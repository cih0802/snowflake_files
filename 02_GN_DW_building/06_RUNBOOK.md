---
project_id: GN_DW
doc_type: operations_runbook
chapter: "06_RUNBOOK"
index: "00_INDEX.md"
language: ko (설명) / en (명령어)
target_audience: 운영팀 / 데이터 엔지니어
last_updated: 2026-07-22
---

# GN_DW 운영 매뉴얼 (Runbook)

> 본 문서는 GN_DW 데이터 웨어하우스의 **일상 운영 절차 및 장애 대응 방법**을 기술한다(라이브 2026-07-22 기준).
> 설계 상세는 `04_운영 확인.md`, 전체 아키텍처는 `05_ARCHITECTURE.md` 참조.
> ⚠️ **ETL은 dbt 파이프라인(`GN_DW.OPS.DW_PIPELINE`)으로 운영**한다. 구설계의 Task DAG·정제 프로시저·`ETL_LOG`는 폐기되었으므로, 아래 절차는 dbt 기준이다.

---

## 목차

1. [일상 점검 (Daily Check)](#1-일상-점검-daily-check)
2. [dbt 파이프라인 장애 대응](#2-dbt-파이프라인-장애-대응)
3. [dbt 수동 실행](#3-dbt-수동-실행)
4. [BRONZE 적재 이상](#4-bronze-적재-이상)
5. [Warehouse / 크레딧 이상](#5-warehouse--크레딧-이상)
6. [Agent / Semantic View 장애](#6-agent--semantic-view-장애)
7. [Streamlit 앱 (미배포)](#7-streamlit-앱-미배포)
8. [보안 사고 대응](#8-보안-사고-대응)
9. [긴급 연락망 / 에스컬레이션](#9-긴급-연락망--에스컬레이션)
10. [Phase-1 검증 로그 (2026-07-22)](#10-phase-1-검증-로그-2026-07-22)
11. [🔴 전체 재구축 순서 (TEARDOWN → 재생성)](#11--전체-재구축-순서-teardown--재생성)

---

## 1. 일상 점검 (Daily Check)

> ETL은 현재 온디맨드 dbt 실행(정기 cron Task 미도입). 실행 직후 아래 항목을 확인한다.

### 1.1 dbt 파이프라인 실행 상태

```sql
-- dbt 프로젝트 최근 실행/버전 확인
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;
```

**정상:** SILVER 32 + GOLD 24 + WIDE 9 = 65 models green (dbt run/test 성공)
**이상:** dbt run/test 실패 → [2. dbt 파이프라인 장애 대응](#2-dbt-파이프라인-장애-대응)

### 1.2 계층별 적재 결과 확인

```sql
-- 계층별 테이블 수 확인 (기대: BRONZE 48 / SILVER 32 / GOLD 24 base + 9 view)
SELECT table_schema, table_type, COUNT(*) AS cnt
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema NOT IN ('INFORMATION_SCHEMA','PUBLIC')
GROUP BY table_schema, table_type
ORDER BY table_schema, table_type;
```

**정상:** BRONZE_CRM 43 · BRONZE_AGENCY 3 · BRONZE_ERP 1 · BRONZE_GA4 1 · SILVER 32 · GOLD 24 BASE + 9 VIEW · SERVING 2 VIEW(+SV 5·Agent 2)
**참고:** `FACT_TARGET_BIZ`=0행은 정상(E-6 CRM 사업목표 입고 대기).

### 1.3 BRONZE 적재 신선도

```sql
-- 대표 CRM 원천 테이블 최종 적재 시점 (BRONZE는 원천별 스키마 분리)
-- 적재 메타 컬럼은 _LOAD_DT (BRONZE 적재 DDL 기준). 대표 테이블=정기회원 마스터.
SELECT 'TM_MM_FDRM_MBER_INFO' AS table_name,
       MAX(_LOAD_DT) AS last_loaded,
       DATEDIFF(HOUR, MAX(_LOAD_DT), CURRENT_TIMESTAMP()) AS hours_stale
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
HAVING DATEDIFF(HOUR, MAX(_LOAD_DT), CURRENT_TIMESTAMP()) > 24;
```

**이상 시:** [4. BRONZE 적재 이상](#4-bronze-적재-이상) 참조

### 1.4 크레딧 사용량

```sql
-- 당월 Warehouse별 크레딧 누적
SELECT warehouse_name, SUM(credits_used) AS credits_mtd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATE_TRUNC('MONTH', CURRENT_DATE())
GROUP BY warehouse_name
ORDER BY credits_mtd DESC;
```

---

## 2. dbt 파이프라인 장애 대응

### 2.1 장애 확인 흐름

```
dbt run/test 실패 확인
       │
       ├── SILVER 모델 실패
       │      → 원천(BRONZE) 스키마 변경/누락 또는 정제 로직 오류
       │      → 조치: 실패 모델 로그 확인 → 수정 후 dbt run --select <model>
       │
       ├── GOLD 모델 실패
       │      → SILVER 입력 부재 또는 star schema 로직 오류
       │      → 조치: 상류 SILVER 상태 확인 → dbt run --select <model>+ (하위 포함)
       │
       ├── WIDE VIEW 실패
       │      → 참조 FACT/DIM 부재
       │      → 조치: GOLD 재빌드 후 view 재생성
       │
       └── dbt test 실패 (not_null/unique/relationships)
              → relationships는 severity:warn(메달리온 BP)로 대개 경고
              → 핵심 PK/not_null error는 원천 데이터 품질 이슈 → 20_issue 원장 확인
```

### 2.2 dbt 수동 재실행

```sql
-- Snowflake 네이티브 dbt 프로젝트 실행 (Role/WH 전환 후)
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_ETL_WH;

-- 전체 빌드
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- 특정 계층/모델만
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='run --select silver';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='run --select gold';
```

> 워크스페이스에서 개발/디버그 시 `10_dbt_pipeline/`에서 `dbt build`(로컬 CLI) 사용. 배포·버전은 `10_dbt_pipeline/deploy_dbt_project.sql` 참조.

---

## 3. dbt 수동 실행

### 3.1 전체 파이프라인 재실행

```sql
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_ETL_WH;

EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';   -- run + test
```

### 3.2 개별 모델 실행

```sql
-- 예: 회원 월 팩트만 재빌드 (+ 하위 WIDE/의존 포함)
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='run --select FACT_MEMBER_MONTHLY+';
```

### 3.3 GOLD DDL 변경 반영

> 🔴 **[2026-08-04 O30 교정] 종전 이 절은 *"06_DDL.sql 재실행 후 dbt build"* 라고만 적혀 있었다.**
> `06_DDL.sql` 은 전부 `CREATE OR REPLACE TABLE` 이다 — **재실행하면 데이터·FK·GRANT 가 전부 파괴**되고,
> 정본 DDL 에 접히지 않은 물리 `ALTER` 변경도 함께 소실된다. 실제로 2026-08-03 이 경로로
> **`dbt build` ERROR 3 · SKIP 68 · GOLD 뷰 5종 소실 · SERVING 전멸** 사고가 났다(문서10 §19 · P57).
> **평상시 컬럼 변경에 `06_DDL.sql` 을 재실행하지 말 것.** 재실행은 §11 전체 재구축 때만이다.

**평상시 컬럼 추가·변경 절차 (데이터 보존)**

```sql
-- ① 물리에 ALTER 로 반영 (CREATE OR REPLACE 금지 — FK·GRANT 보존)
USE ROLE GN_DW_ADMIN;
ALTER TABLE GN_DW.GOLD.<T> ADD COLUMN IF NOT EXISTS <C> <TYPE>;
ALTER TABLE GN_DW.GOLD.<T> ALTER COLUMN <C> COMMENT '<...>';   -- RENAME 은 구 COMMENT 를 승계한다(P33)

-- ② 🔴 같은 세션에 정본 DDL 도 고친다 = 03_top-down_gold/06_DDL.sql
--    (SILVER 는 04_silver_design/08_SILVER_테이블DDL_20260714.sql)
--    이 단계를 빠뜨리면 다음 재구축이 ①을 조용히 되돌린다 — O30 의 직접 원인이다.

-- ③ 모델 산출 컬럼도 맞춘다 (10_dbt_pipeline/models/…)
--    ⚠️ dbt incremental 은 '대상 테이블에 없는 산출 컬럼'을 에러 없이 버린다.
--       모델에만 있는 컬럼은 무증상으로 폐기되므로 테스트로 잡히지 않는다.

-- ④ dbt build
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';
```

**완료 판정 (문서 아님 — 실측)**

```sql
-- 정본 DDL ↔ 물리 컬럼 집합이 양방향으로 일치하는지 확인한다.
--   06_DDL.sql 의 해당 CREATE 문을 임시 이름으로 실행해 컬럼을 비교하고 DROP 한다.
--   (본 방식으로 2026-08-04 DIM_MEMBER 30컬럼 == 물리 30컬럼 확인)
SELECT COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='<T>' ORDER BY ORDINAL_POSITION;
```

> ⛔ 예측(Forecast) 파이프라인은 제외 결정(2026-07-10)으로 미운영.

### 3.4 데이터 품질 검증 (수동)

```sql
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='test';
-- not_null/unique/relationships 결과 확인. relationships=warn은 관측용.
```

---

### 3.5 산출물 생성기 회귀 테스트 (골든) — `30_output_share` 를 만지면 반드시 실행

**왜** — `scripts/` 에는 2026-08-07 까지 test·golden 이 **0건**이었다. 그래서 생성기 사고 2건이
**오류를 내지 않은 채** 통과했고 우연히 발견됐다(O47-B 앵커 동점 · P98 라벨 사전 오염).
이 테스트가 그 우연 의존을 끊는다. **SQL 접속·census 불요** — 산출물 파일과 생성기 소스만 읽으므로
언제든 몇 초에 돌아간다.

```bash
python3 scripts/test_generators.py                  # 검사 (18 assertion · exit 1 = 회귀)
python3 scripts/test_generators.py --self-check     # 🔴 일부러 깨뜨려 검출되는지 확인 (6종)
python3 scripts/test_generators.py --update-golden   # 차이를 **전량 규명한 뒤에만** 골든 갱신
```

| 항목 | 무엇을 잡는가 |
|---|---|
| `G` 골든 대조 | `04·05·06·08·09` 의 행수·판정 분포 + **섹션→앵커 매핑 29건 전량** + 라벨 사전 상태 (25지표). 산출물 결손·파싱 실패는 **골든과 별개의 독립 불합격**(`G.artifacts-readable`) |
| `T1` | 앵커 동점 시 판정이 삽입 순서로 뒤집히는 사고(O47-B) — `pick_anchor()` 200회 셔플 동일 |
| `T2` | 수기 문서(`05_필드 인벤토리.md`)가 생성기 라벨 사전을 오염(P98) — **도달불가 색인 키 0건** |
| `T3` | 생성기 간 출력 문자열 계약(`SV metric` 접두 · P92) — 상수·05 소스·05 산출물·09 산출물 4중 |
| `T4` | P97·P100 절차 강제 — 「불가·경합」 근거에 **실제 식별자가 백틱으로 등장**하는지 기계 검사 |

🔴 **`--self-check` 6종은 장식이 아니다** — 이 절차가 실제로 결함 2건을 잡았다(O48-B 자기검토):
① 종전 골든은 앵커를 **카운트**로만 떠서 **행수가 같은 두 섹션의 앵커 교환**을 통과시켰다(= O47-B
사고 형태를 정작 놓쳤다) → 섹션→앵커 매핑 전량 고정으로 교정. ② 산출물 1종이 없으면 **크래시**로
죽어 나머지 검사가 전부 미실행이었다 → 결손을 **판정**으로 보고하도록 교정.
⇒ 검사기를 고쳤으면 `--self-check` 를 **함께** 돌린다. 통과만 하는 테스트는 통과를 증명하지 않는다.

🔴 **골든의 성격** — 「데이터가 이 값이어야 한다」가 아니라 **「생성기가 어제와 같은 판정을 내려야
한다」** 는 계약이다. 데이터 입고로 수치가 바뀌는 것은 정상이며, 그때는 **차이를 전량 규명한 뒤**
`--update-golden` 한다(PROC-3(c)). 실패 시 차이 내역이 전량 출력되므로 개수만 보고 갱신하지 말 것.

⚠️ 생성기(`gen_*.py`)를 고쳤으면 **즉시 스테이지 업로드 후 `cortex ws ls` 로 확인**한다(§9 P102 —
`/workspace` 마운트의 `ls` 는 반영 증거가 아니다).

---

## 4. BRONZE 적재 이상

### 4.1 증상별 대응

| 증상 | 원인 | 조치 |
|---|---|---|
| 24시간 이상 미갱신 | 외부팀 적재 미실행 | LOADER 팀에 확인 요청 |
| 행 수 급감 (>50% 감소) | 소스 시스템 장애 또는 적재 오류 | LOADER 팀에 재적재 요청 |
| 중복 행 급증 | 적재 멱등성 미보장 | 중복 제거 후 dbt 재빌드 |
| 스키마 변경 (컬럼 추가/삭제) | 소스 시스템 DDL 변경 | BRONZE DDL 수정 → SILVER dbt 모델 수정 |

### 4.2 중복 행 제거 (긴급)

```sql
-- 예: TM_MM_FDRM_MBER_INFO(정기회원 마스터) PK(MBER_NO) 기준 중복 제거
-- ⚠️ BRONZE는 원천별 스키마 분리: CRM 테이블은 GN_DW.BRONZE_CRM. 적재 메타=_LOAD_DT
USE ROLE GN_DW_ENGINEER;

CREATE OR REPLACE TABLE GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO AS
SELECT * EXCLUDE rn FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY _LOAD_DT DESC) AS rn
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
)
WHERE rn = 1;

-- 이후 SILVER 이하 재빌드
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='run --select CRM_MEMBER+';
```

---

## 5. Warehouse / 크레딧 이상

### 5.1 Resource Monitor 트리거 시

> ⚠️ Resource Monitor는 현재 미배포(설계안, 04_운영 확인.md 8.1). 아래는 운영 승격 후 기준.

| 임계 | 동작 | 대응 |
|---|---|---|
| 75% (ETL) / 80% (Account) | 알림 발송 | 비용 추이 확인, 이상 쿼리 조사 |
| 90% (ETL) | WH SUSPEND | 긴급 쿼리 완료 대기 → 다음 주기 리셋 또는 한도 상향 |
| 100% | SUSPEND IMMEDIATE | 즉시 중단. 운영 영향 확인 후 한도 조정 |

### 5.2 한도 긴급 상향 (RM 배포 후)

```sql
USE ROLE ACCOUNTADMIN;
ALTER RESOURCE MONITOR RM_ETL SET CREDIT_QUOTA = 300;  -- 200 → 300
```

### 5.3 비정상 쿼리 조사

```sql
-- 최근 24시간 고비용 쿼리 TOP 10
SELECT query_id, user_name, role_name, warehouse_name,
       total_elapsed_time/1000 AS elapsed_sec,
       credits_used_cloud_services,
       SUBSTR(query_text, 1, 200) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC
LIMIT 10;
```

### 5.4 WH 수동 재개

```sql
ALTER WAREHOUSE GN_DW_ETL_WH RESUME;
```

---

## 6. Agent / Semantic View 장애

### 6.1 증상별 대응

| 증상 | 원인 | 조치 |
|---|---|---|
| Agent 응답 없음 / 타임아웃 | Cortex 서비스 일시 장애 | 5분 후 재시도. 지속 시 Support 문의 |
| "권한 없음" 오류 | SERVING USAGE 미부여 또는 GOLD SELECT 누락 | 권한 확인 (아래 SQL) |
| SQL 생성 오류 (잘못된 컬럼/테이블) | VQR/SV 정의 불일치 | Semantic View 정의 점검 (`05_SV-Agent_ai/`) |
| 응답은 오지만 결과 비어있음 | 참조 FACT 미적재(BLOCKING-5 비활성 measure) | 해당 measure 활성 여부 확인 (SV comment) |
| 납부율 등 비율 왜곡 | 기간 스코프 미적용 | custom instruction 기간스코프 강제(P10) 확인 |

### 6.2 권한 점검

```sql
-- Viewer가 Agent를 사용할 수 있는지 확인
USE ROLE GN_DW_VIEWER;
SHOW GRANTS ON SCHEMA GN_DW.SERVING;

-- Agent 사용 권한 (라이브: AGENT_MEMBER / AGENT_OVERALL)
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;

-- CoWork Agent text-to-SQL은 호출자 세션에서 base(GOLD)에 직접 실행
SELECT * FROM GN_DW.GOLD.WIDE_MEMBER_MONTHLY LIMIT 1;
```

### 6.3 Semantic View 테스트

```sql
-- 배포 SV 목록 확인 (5개)
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;

-- Snowsight Agent UI(CoWork)에서 단순 질문으로 확인
-- ⚠️ [6-C] 트라이얼 계정은 DATA_AGENT_RUN 차단 → NL 스모크는 paid 이관 후.
```

---

## 7. Streamlit 앱 (미배포)

> **라이브 실측: SERVING에 배포된 Streamlit 앱 없음(0개).** 현재 소비는 Cortex Agent(CoWork) + Semantic View 중심.
> 향후 배포 시 `GN_DW.SERVING`에 owner's rights, query WH=`GN_DW_ANALYTICS_WH`로 운영하며 아래 명령으로 상태 점검한다.

```sql
USE ROLE GN_DW_ADMIN;
SHOW STREAMLITS IN SCHEMA GN_DW.SERVING;   -- 현재 0건
```

---

## 8. 보안 사고 대응

### 8.1 계정 잠김 (네트워크 정책 오설정)

```
⚠️  본인 IP가 ALLOWED LIST에서 누락되면 즉시 접속 불가.
    Snowflake Support에 계정 잠금 해제 요청 필요.
```

**예방:**
- 네트워크 정책 변경 전 반드시 본인 IP 포함 확인
- 변경은 항상 테스트 후 적용

**긴급 복구 (Support 요청 전 시도):**
```sql
USE ROLE SECURITYADMIN;
ALTER ACCOUNT UNSET NETWORK_POLICY;  -- 정책 일시 해제
```

### 8.2 비정상 로그인 감지

```sql
SELECT user_name, client_ip, error_code, error_message, event_timestamp
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
  AND is_success = 'NO'
ORDER BY event_timestamp DESC;
```

### 8.3 권한 변경 감사

```sql
SELECT query_text, user_name, role_name, execution_status, start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
  AND (query_text ILIKE '%GRANT%' OR query_text ILIKE '%REVOKE%')
  AND query_type != 'SHOW'
ORDER BY start_time DESC;
```

### 8.4 데이터 유출 의심

```sql
SELECT user_name, role_name, query_type,
       rows_produced, bytes_scanned,
       SUBSTR(query_text, 1, 300) AS query_preview
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
  AND (query_type IN ('COPY', 'UNLOAD') OR rows_produced > 1000000)
ORDER BY rows_produced DESC
LIMIT 20;
```

---

## 9. 긴급 연락망 / 에스컬레이션

### 9.1 에스컬레이션 단계

```
Level 1 (15분 이내 대응)
  │  담당: GN_DW_ENGINEER (데이터 엔지니어)
  │  범위: dbt 파이프라인 실패, 모델 오류, 일반 운영 이슈
  │
Level 2 (30분 이내 대응)
  │  담당: GN_DW_ADMIN (관리자)
  │  범위: 권한 문제, DDL 변경, Warehouse 한도 조정, 보안 이슈
  │
Level 3 (1시간 이내 대응)
  │  담당: ACCOUNTADMIN + Snowflake Support
  │  범위: 계정 잠김, 서비스 전체 장애, 크레딧 긴급 상향
  │
외부 (SLA별 대응)
     담당: LOADER 팀 (외부)
     범위: BRONZE 적재 미실행, 소스 데이터 품질 이슈
```

### 9.2 연락처 (템플릿)

| 역할 | 담당자 | 연락처 | 비고 |
|---|---|---|---|
| GN_DW_ENGINEER | (이름) | (전화/슬랙) | 1차 대응 |
| GN_DW_ADMIN | (이름) | (전화/슬랙) | 2차 에스컬 |
| ACCOUNTADMIN | (이름) | (전화/슬랙) | 긴급 |
| LOADER 팀 | (이름) | (이메일) | BRONZE 적재 |
| Snowflake Support | - | support.snowflake.com | 서비스 장애 |

> **참고:** 실제 담당자 정보는 조직 정책에 따라 기입할 것.

---

## 10. Phase-1 검증 로그 (2026-07-22)

> **Phase 정의:** BRONZE 원천이 **부분 입고**(CRM 43 전수 + GA4 1일 샤드·ERP 예산·AGENCY 스캐폴드; 전기간·모금성비용·사업목표 등 잔여 입고 대기)인 상태에서 SV·Agent를 **Phase-1**(활성 measure만 노출)로 생성·검증했다. 본 로그는 **Phase-1 기준** 결과이며, 잔여 원천 입고 시 Phase-2에서 재검증한다.

### 10.1 소유권 이관 (B.5) — 실행·검증 완료
- `GN_DW` DB·전 스키마(PUBLIC·BRONZE_*·SILVER·GOLD·OPS·SECURITY)·전 테이블(BRONZE 48·SILVER 32·GOLD 24)·GOLD 뷰·`DBT PROJECT` → **GN_DW_ADMIN 소유**로 이관(`COPY CURRENT GRANTS`). INFORMATION_SCHEMA 제외, SERVING 기존 ADMIN.
- WIDE 뷰 9개 → **GN_DW_ENGINEER 소유**(dbt가 `CREATE OR REPLACE VIEW`로 재생성하는 산출물).
- 검증: `INFORMATION_SCHEMA.SCHEMATA`/`.TABLES` owner = GN_DW_ADMIN 전건 확인 ✅.

### 10.2 dbt 실행 권한 (D.5) — ENGINEER 최소권한
- 부여: GOLD `INSERT/UPDATE/DELETE/TRUNCATE`(all+future) · SILVER `INSERT/TRUNCATE`(all+future) · OPS `USAGE` · DBT PROJECT `USAGE/MONITOR`. **GOLD `CREATE TABLE` 미부여**(dbt 적재 전용).
- `profiles.yml` role=`GN_DW_ENGINEER`, wh=`GN_DW_ETL_WH`.

### 10.3 dbt build (GN_DW_ENGINEER 실행) — GREEN
```
Done. PASS=211 WARN=21 ERROR=0 SKIP=0 TOTAL=232   (87.5s)
56 incremental models + 9 view models + 167 data tests
```
- **CREATE TABLE 없이** dim(merge)·fact(append+pre-hook TRUNCATE) 완주 → 최소권한 설계 검증 ✅.
- 대표 적재 행수: SILVER `CRM_PAYMENT_BILLING` 47,521,872 · `CRM_SEND_MEMBER` 38,471,525 / GOLD `FACT_MEMBER_MONTHLY` 40,054,883 · `FACT_SERVICE_EVENT` 38,470,780 · `FACT_TARGET_BIZ` **0행(E-6 사업목표 입고 대기, 정상)**.

### 10.4 comment 보존 — 100% 유지
| 테이블 | 컬럼 | comment |
|---|---|---|
| DIM_CAMPAIGN | 15 | 15 |
| DIM_MEMBER | 22 | 22 |
| FACT_MEMBER_MONTHLY | 52 | 52 |
- dbt 적재-전용(구조=06_DDL 소유 GN_DW_ADMIN) → 재적재 후에도 컬럼 comment 전건 보존 ✅.

### 10.5 WIDE 뷰 재생성 + 소비 grant 자동 재부여
- `WIDE_MEMBER_MONTHLY` OWNERSHIP = GN_DW_ENGINEER, 소비 3역할(ANALYST·VIEWER·SERVICE) `SELECT` **자동 재부여** 확인(ADMIN이 스키마에 건 FUTURE VIEW grant 상속) ✅.

### 10.6 dbt test — WARN 21 / ERROR 0 (의도된 경고)
- 21 WARN = `severity:warn` 관계/not_null (미매칭 FK가 센티넬 SK=0 Unknown 라우팅). 대표: `FACT_SERVICE_EVENT`↔DIM_MEMBER 31,486 · `EVENT_PARTICIPATION` 9,480 · `CRM_SEND_MEMBER` not_null 745. 메달리온 BP(relationships=warn)에 따른 관측용이며 **핵심 PK not_null/unique는 전건 PASS, ERROR 0**.

### 10.7 Phase-1 한계 (Phase-2 재검증 대상)
- SV **5 배포(최종 7)** / Agent **2 배포(최종 3)** — 활성 measure만 노출. 비활성 measure(연 편성예산·집행추정·모금성비용·성공/실패/오픈·+5일 코호트·조직/캠페인/후원사업별 분해 등)는 **원천 입고 대기**로 SV comment에 비활성 명시.
- 잔여 입고(GA4 전기간·ERP 모금성비용·CRM 사업목표 E-6 등) 완료 시 → SILVER/GOLD 재적재 → SV metric 활성화(구조 불변) → Phase-2 검증.
- ⚠️ [6-C] 트라이얼 계정 `DATA_AGENT_RUN` 차단 → NL 스모크 테스트는 paid 이관 후.

---

## 부록: 자주 사용하는 운영 명령어

```sql
-- ═══════════════════════════════════════
-- dbt 파이프라인
-- ═══════════════════════════════════════
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;                          -- 프로젝트 목록
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;                     -- 상세/버전
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';         -- 전체 빌드
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='run --select silver';  -- 계층 실행

-- ═══════════════════════════════════════
-- Warehouse 관련
-- ═══════════════════════════════════════
ALTER WAREHOUSE GN_DW_ETL_WH SUSPEND;                          -- 즉시 중지
ALTER WAREHOUSE GN_DW_ETL_WH RESUME;                           -- 재개
ALTER WAREHOUSE GN_DW_ANALYTICS_WH SET WAREHOUSE_SIZE = 'LARGE';  -- 임시 스케일업

-- ═══════════════════════════════════════
-- 오브젝트 확인
-- ═══════════════════════════════════════
SHOW TABLES IN SCHEMA GN_DW.BRONZE_CRM;    -- CRM 원천 (GA4/ERP/AGENCY는 BRONZE_GA4/ERP/AGENCY)
SHOW TABLES IN SCHEMA GN_DW.SILVER;
SHOW VIEWS IN SCHEMA GN_DW.GOLD;           -- WIDE VIEW 9
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;   -- SV 5
SHOW AGENTS IN SCHEMA GN_DW.SERVING;           -- AGENT_MEMBER / AGENT_OVERALL
SHOW STREAMLITS IN SCHEMA GN_DW.SERVING;       -- 현재 0

-- ═══════════════════════════════════════
-- 권한 확인
-- ═══════════════════════════════════════
SHOW GRANTS TO ROLE GN_DW_VIEWER;
SHOW GRANTS ON SCHEMA GN_DW.SERVING;
SHOW GRANTS ON DATABASE GN_DW;
```

---

## 11. 🔴 전체 재구축 순서 (TEARDOWN → 재생성)

> **작성 2026-08-04 (O30 사고 후속) · 정본 진단 = `20_issue/10_진단_원인분석.md` §19**
>
> 🔴 **이 절은 "데이터를 버리고 처음부터 만든다"는 결정이 이미 내려진 경우에만 쓴다.**
> 평상시 컬럼 변경은 **§3.3** 이다. 이 절의 ①②는 `CREATE OR REPLACE TABLE` 이라
> **데이터·FK·GRANT 를 전부 파괴**한다.

### 11.0 사고 이력 — 왜 이 절이 생겼는가

2026-08-03 20:55~21:38 전체 재구축이 실행됐고, **정본 DDL 에 접히지 않은 물리 `ALTER` 변경만
되돌아가** `dbt build` 가 깨졌다.

| 결과 | 실측 |
|---|---|
| dbt build | ERROR 3 · SKIP 68 (모델 9 + 테스트 59) |
| 소실된 변경집합 | O26 SILVER 개명 2컬럼 · O27 `DIM_MEMBER` 4추가/3삭제 — **둘 다 정본 DDL 미동기화** |
| 무사한 변경집합 | DEC-30 구조변경 · O25 SILVER 38컬럼 · O28/O29 COMMENT 가드 — **정본 DDL 에 접혀 있었다** |
| 부수 피해 | GOLD 뷰 5종 미생성 · SERVING 객체 0건 · 빈 테이블 9종 |

**교훈 P57**: 재구축은 **정본 DDL 파일을 실행**한다. 정본에 접히지 않은 `ALTER` 는
「다음 재구축까지만 유효한 임시 패치」다.

### 11.1 사전 점검 (재구축 전에 반드시)

```sql
-- ① 정본 DDL ↔ 현재 물리 구조가 어긋난 곳이 없는지 먼저 확인한다.
--    어긋난 채로 재구축하면 그 차이가 '조용히' 사라진다.
--    → 모델 산출 컬럼 vs 물리 컬럼 양방향 대조 (§3.3 완료 판정과 동일 방법)

-- ② 물리에만 있는 ALTER 변경이 남아 있으면 지금 정본 DDL 에 접는다.
--    미접힘 이력: O26(→08_SILVER_테이블DDL) · O27(→06_DDL.sql) — 2026-08-04 접기 완료

-- ③ BRONZE 재적재 가능 여부 확인 (원천 파일·스테이지 존재)
SELECT TABLE_SCHEMA, COUNT(*) TBLS, SUM(ROW_COUNT) ROWS
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA LIKE 'BRONZE%' AND TABLE_TYPE='BASE TABLE' GROUP BY 1;
```

### 11.2 현재 상태 (2026-08-04 실측) — 어디까지 되어 있는가

| 단계 | 상태 | 근거 |
|---|---|---|
| 0 환경·RBAC (`07_ENVIRONMENT_RBAC_setup.sql`) | ✅ 완료 | 역할 6종 생성 2026-08-03 20:55 · 스키마 11종(OPS·SERVING 포함) 존재 |
| 0b BRONZE | ✅ 완료 | 51테이블 · 112,512,201행 |
| ① `06_DDL.sql` (GOLD 28) | ✅ 완료 | — |
| ② `08_SILVER_테이블DDL` (SILVER 38) | ✅ 완료 | — |
| **정본 DDL ↔ 물리 정합** | ✅ **불일치 0** | **66테이블 전수 대조**(정본 선언 컬럼 vs `INFORMATION_SCHEMA`) |
| DBT PROJECT `GN_DW.OPS.DW_PIPELINE` | 🔴 **미존재** | `SHOW DBT PROJECTS IN DATABASE GN_DW` = 0행 (재구축이 삭제) |
| ③ dbt build | 🔴 미완 | 빈 테이블 9종 · GOLD 뷰 5종 미생성 |
| ④ SERVING | 🔴 미완 | SERVING 객체 0건 |

> 🔴 **①②를 다시 실행할 필요가 없다.** 2026-08-04 복구로 물리 구조가 정본 DDL 과 **완전히 일치**한다
> (66테이블 양방향 차집합 0). 재실행하면 **SILVER·GOLD 데이터가 전량 삭제**되고 ③을 다시 돌려야 한다.
> ①②는 **DB 를 처음부터 만들 때만** 쓴다.

### 11.2-B 실행 순서 (지금 시점 · 최소 경로)

```
1) deploy_dbt_project.sql          ← 🔴 DBT PROJECT 가 없다. 3)의 GRANT 전제조건
     10_dbt_pipeline/deploy_dbt_project.sql
     · CREATE SCHEMA GN_DW.OPS (멱등) + GRANT CREATE DBT PROJECT
     · CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE FROM '…/versions/live'
     ⚠️ 이미 있으면 IF NOT EXISTS 가 '아무 일도 안 함' → 구버전이 그대로 실행된다.
        모델을 고친 뒤라면 ALTER DBT PROJECT … ADD VERSION 으로 새 버전을 올려야 한다.
        (2026-08-04 DIM_AD_CREATIVE 모델 수정분이 여기에 해당)

2) dbt build                        ← SILVER·GOLD 적재 + GOLD 뷰 13종 생성
     EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --target dev';
     또는 워크스페이스 직접 실행(project_root='/10_dbt_pipeline')
     ⚠️ 워크스페이스 직접 실행은 live 파일을 읽으므로 1) 없이도 되지만,
        그 경우 3)의 DBT PROJECT GRANT 3줄은 여전히 실패한다.

3) 08_After_Deploy_DBT.sql          ← DBT PROJECT GRANT + SERVING GRANT + CoWork + helper 뷰 2
     02_GN_DW_building/08_After_Deploy_DBT.sql
     · §G.1 SERVING.DIM_MONTH          ← GOLD.DIM_DATE
     · §G.2 SERVING.DIM_MEMBER_CURRENT ← GOLD.DIM_MEMBER  (2026-08-04 O27 반영)
     ⚠️ 역할이 ACCOUNTADMIN ↔ GN_DW_ADMIN 으로 바뀐다. 스크립트의 USE ROLE 을 지킬 것.

4) 05_1 ~ 05_7_SV_DDL_*.sql         ← SV 6종(+05_7 에 SERVING.FACT_AD_COMBINED 동봉)
        🔴 [2026-08-05 O37 분할] 각 파일이 GRANT·스모크까지 포함해 **독립 실행**된다(순서 무관).
           `05_0_SV_DDL.sql` 은 인덱스·공통규약·전체검증 전용 — 실행해도 SV 가 배포되지 않는다.
     05_SV-Agent_ai/05_1_SV_DDL_MEMBER_MONTHLY.sql ... 05_7_SV_DDL_AD.sql
     · 3)의 helper 뷰 2종을 논리테이블로 참조한다(DIM_MEMBER_CURRENT 4곳 · DIM_MONTH 2곳)
     · 🔴 반드시 `USE ROLE GN_DW_ADMIN` 으로 실행(ACCOUNTADMIN 으로 만들면 소유권이 어긋나
       이후 재배포가 권한 오류로 막힌다 — 05 파일 15~16행)

5) 09_1_AGENT_생성.sql              ← Agent **껍데기**만 (최소 스펙·소유권·USAGE grant·CoWork SI)
     05_SV-Agent_ai/09_1_AGENT_생성.sql

6) 09_2_AGENT_버전업.sql            ← 🔴 **스펙 본문 적용. 이 단계를 빼면 Agent 가 아무것도 못 한다**
     05_SV-Agent_ai/09_2_AGENT_버전업.sql
     · 정본 = cortex_project/agents/<AGENT>/agent_spec.yaml (stage 에서 직접 읽는다)
     · `ALTER AGENT … ADD VERSION FROM <stage dir>` → 새 버전 자동 is_default · 이전 버전 보존
     · GRANT·CoWork SI 를 파괴하지 않는다(2026-08-04 실측: USAGE 3종 잔존)
     ⚠️ 성공 메시지가 `Version nullsuccessfully created` 로 보이는 것은 표시 버그다
     🔴 **미실행 시 증상**: Agent 객체는 생기고 UI 에도 보이지만 스펙이
        `{"models":{"orchestration":"auto"}}` — **도구 0개·instruction 0개**로 질의에 답하지 못한다.
        2026-08-04 재구축 후 실제로 이 상태였다(§19-I 최소경로가 이 단계를 누락하고 있었다).

※ O28_O29_COMMENT_GUARD.sql          ← 🔴 실행 대상 아님(2026-08-05 O41). 정본 06_DDL.sql +
                                       WIDE 모델 post_hook 에 접혀 재구축+build 로 복원된다.
                                       파일은 _archive/ 로 이관됨(참조 전용). 11.3 참조
```

> 🔴 **[2026-08-04 교정] 종전 이 목록의 5단계 `13_SV_AD_배포_추가작업.sql` 은 삭제됐다.**
> 그 파일은 `[DEPRECATED 2026-07-31]` 이며 **실행 가능한 라인이 0개**다(전량 주석 · 내용은 05·09 로
> 이관 완료). 실행해도 아무 일이 없으므로 파괴적이지는 않지만 **「했다」는 착각을 만든다.**
> 같은 이유로 `09_AGENT_spec_구현.sql`(구 09)·`02_SERVING_setup.sql` 도 실행 대상이 아니다.
> 그리고 종전 목록은 **`09_2` 를 아예 담고 있지 않았다** — 그래서 Agent 가 껍데기로 남았다.

### 11.2-C 🆕 신규 계정 재현 순서 (BRONZE 만 있는 계정 · 2026-08-04 신설)

> §11.2-B 는 *"이미 만들어진 계정에서 dbt 이후가 날아간 경우"* 의 최소 경로다.
> **DB 를 처음부터 만드는 경우는 아래 순서**이며, ①② 를 반드시 포함한다.

| # | 파일 | 실행 역할 | 산출물 |
|---|---|---|---|
| **0** | `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` | 파일이 SYSADMIN→SECURITYADMIN→ACCOUNTADMIN→GN_DW_ADMIN 으로 전환 | WH 3 · 역할 6 · DATABASE · 스키마 11 · GRANT(FUTURE 포함) · CoWork SI object |
| ① | `03_top-down_gold/06_DDL.sql` | GN_DW_ADMIN | GOLD 28테이블 |
| ② | `04_silver_design/08_SILVER_테이블DDL_20260714.sql` | GN_DW_ADMIN | SILVER 38테이블 |
| ③ | `10_dbt_pipeline/deploy_dbt_project.sql` | ACCOUNTADMIN→GN_DW_ADMIN | `GN_DW.OPS.DW_PIPELINE` |
| ④ | **dbt build** | GN_DW_ADMIN(또는 ENGINEER) | SILVER·GOLD 적재 + GOLD 뷰 13종 |
| ⑤ | `02_GN_DW_building/08_After_Deploy_DBT.sql` | GN_DW_ADMIN↔ACCOUNTADMIN 전환 | DBT PROJECT GRANT · **§G SERVING helper 뷰 2종** · SERVING GRANT · CoWork |
| ⑥ | `05_SV-Agent_ai/05_1`~`05_7_SV_DDL_*.sql` | 🔴 GN_DW_ADMIN | SV **8종** + 각 파일 GRANT·스모크 (+`05_7` 에 `FACT_AD_COMBINED`). **파일 간 순서 무관·독립 실행**(2026-08-05 O37 분할). 🔴 **[2026-08-05 교정] 종전 "6종" 은 stale** — 실측 배포 8종 = `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_MEMBER_COHORT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`·`SV_BUDGET`·`SV_AD`·`SV_DEV_ACHIEVEMENT`(O38 신설). ⚠️ `05_SV_DDL.sql` 은 인덱스·전체검증 전용이라 실행해도 SV 가 만들어지지 않는다 |
| ⑦ | `05_SV-Agent_ai/09_1_AGENT_생성.sql` | GN_DW_ADMIN | Agent 껍데기 2종 |
| ⑧ | `05_SV-Agent_ai/09_2_AGENT_버전업.sql` | GN_DW_ADMIN | 🔴 Agent 스펙 본문 |

🔴 **0 을 건너뛰면 ① 이 첫 줄에서 죽는다** — `06_DDL.sql` 41~42행이 `USE ROLE GN_DW_ADMIN` ·
`USE WAREHOUSE GN_DW_DEV_WH` 이고 둘 다 `07` 이 만든다. `SILVER`·`GOLD`·`SERVING`·`OPS` 스키마도 없다.
**BRONZE 가 이미 있는 계정이어도 0 은 실행한다** — `07` 의 BRONZE 관련 구문은 전부 `IF NOT EXISTS`
(스키마 생성·GRANT)이며 **BRONZE 테이블·데이터는 건드리지 않는다.**

⚠️ ③ 의 `deploy_dbt_project.sql` 은 현재 Step 1-2(`ALTER … ADD VERSION <별칭>`)와 Step 3(build)이
주석 해제 상태다. 신규 계정에서 통째로 실행하면 `CREATE`(VERSION$1) 직후 **동일 내용의 VERSION$2** 가
생긴다(무해하나 불필요). 신규 계정에서는 **Step 1-1 → Step 2 → Step 3** 만 실행한다.
반대로 ④ 는 그 Step 3 에 포함돼 있으므로 별도 실행이 불요할 수 있다 — 파일 상태를 보고 판단한다.

**①② 를 다시 실행하지 말아야 하는 경우** = §11.2 참조(기존 계정). 두 파일은 전부
`CREATE OR REPLACE TABLE` 이라 **데이터·FK·GRANT 를 파괴**한다.


**의존 관계 요약** (§11.2-B·§11.2-C 공통)

| 산출물 | 선행 필요 | 이유 |
|---|---|---|
| `06_DDL.sql`·`08_SILVER_테이블DDL` | **`07` 역할·WH·스키마** | 첫 줄이 `USE ROLE GN_DW_ADMIN`·`USE WAREHOUSE GN_DW_DEV_WH` |
| `08` 5~7행 GRANT | **DBT PROJECT 객체** | `GRANT USAGE ON DBT PROJECT …` |
| `08` §G 뷰 2종 | GOLD 테이블 **구조**만 | 데이터 불요 → dbt build 전후 무관 |
| `05_1`~`05_7_SV_DDL_*.sql` | `08` §G 뷰 2종 | SV 논리테이블로 참조 |
| 의미있는 SV 결과 | dbt build | 데이터가 있어야 질의가 답을 낸다 |
| **Agent 가 실제로 답하는 것** | **`09_1` → `09_2` 둘 다** | `09_1` 은 껍데기만 만든다. 스펙(도구·instruction)은 `09_2` 가 넣는다 |
| `09_2` | `05_1`~`05_7_SV_DDL_*.sql` | 스펙 `tool_resources` 가 SV 를 참조한다(SV 부재 시 도구가 깨진다) |

---

### 11.3-B ✅ [해소] SERVING helper 뷰 — 정본은 `08_After_Deploy_DBT.sql` §G 였다

> 🔴 **2026-08-04 최초 판정 정정.** 나는 이 항목을 *"실행 정본 유실(BLOCKER)"* 로 등재했으나 **틀렸다.**
> `02_SERVING_setup.sql` 스텁이 *"07_ENVIRONMENT_RBAC_setup.sql 로 이관"* 이라고 적어서 07 과
> `_archive` 만 확인하고 단정했다. 실제 정본은 **`08_After_Deploy_DBT.sql` §G** 다.
> **스텁의 이관 안내가 틀린 파일을 가리키고 있었고, 나는 그것을 검증 없이 따라갔다.**

**실제로 존재하는 결함은 다른 것이었다** — `08` §G.2 가 O27 을 반영하지 않았다.

| 항목 | 내용 |
|---|---|
| 증상 | `SERVING.DIM_MEMBER_CURRENT` 생성문이 `NEW_EXISTING_FLAG`·`LAST_CAMPAIGN`·`CURRENT_SPONSORSHIP` 을 SELECT — O27 이 `GOLD.DIM_MEMBER` 에서 DROP 한 컬럼 |
| 확인 | 동일 SELECT 를 컴파일 → `invalid identifier 'NEW_EXISTING_FLAG'` (실측) |
| 영향 | 위 순서 3) 이 **실패**하고, 그 결과 4) `05_*_SV_DDL_*.sql` 도 helper 뷰 부재로 실패 |
| 조치 | ✅ 3컬럼 제거(2026-08-04). SV 는 이 3컬럼을 참조하지 않는다(`05_1~05_7_SV_DDL_*.sql` 실측 0건) → 소비 영향 0. 수정 후 컴파일 검증 통과 |

📌 **O27 이 번진 산출물은 4개였다**: `06_DDL.sql`(정본) · `GOLD.DIM_MEMBER`(물리) ·
`10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql`(모델) · **`08_After_Deploy_DBT.sql`(SERVING 뷰)**.
구조 변경 시 **소비 뷰까지 역방향으로 추적**해야 한다 — 모델·DDL 만 보면 4번째를 놓친다.

**남은 항목(BLOCKER 아님) — `DIM_MEMBER_CURRENT` 2판 공존**

| 객체 | 소유 | 용도 | 컬럼 |
|---|---|---|---|
| `SERVING.DIM_MEMBER_CURRENT` | `08` §G.2 | **SV 전용** fan-out 차단 | 19 (REGION·AGE_BAND·FIRST_SPONSORSHIP·LAST_STOP_DATE 포함) |
| `GOLD.DIM_MEMBER_CURRENT` | dbt 모델 (DEC-27 §17-A) | **분석가 진입점** | 20 (위 4컬럼 미노출 · `MEMBER_TYPE`·감사컬럼 포함) |

소비자가 달라 **의도적 분리로 설명 가능**하나 문서에 명시돼 있지 않았다 → 양쪽 COMMENT·헤더에
역할 분리를 명기했다(2026-08-04). ⬜ 잔여: `DIM_MEMBER_CURRENT.sql` 헤더가 *"전건 NULL 7컬럼 미노출"*
로 **이제 존재하지 않는 3컬럼을 열거**한다 — 거짓 주석 회수 대상(P33 ③). build 실패 요인은 아니다.

### 11.4 재구축 후 검증

```sql
-- ① 계층별 객체·행수
SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*) OBJS, SUM(ROW_COUNT) ROWS
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('BRONZE_CRM','BRONZE_AGENCY','BRONZE_ERP','BRONZE_GA4','SILVER','GOLD','SERVING')
GROUP BY 1,2 ORDER BY 1,2;
--   기대: GOLD 테이블 28 · GOLD 뷰 13 · SILVER 테이블 38 · SERVING 객체 > 0

-- ② 빈 테이블 (원래 0행인 FACT_TARGET_BIZ·CRM_BIZ_TARGET 외에 있으면 적재 실패)
SELECT TABLE_SCHEMA, TABLE_NAME FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA IN ('SILVER','GOLD') AND ROW_COUNT=0
ORDER BY 1,2;

-- ③ COMMENT 커버리지 (SV description 으로 소비되므로 결손은 무증상 오답이 된다)
SELECT TABLE_SCHEMA, COUNT(*) COLS, COUNT_IF(COMMENT IS NULL OR COMMENT='') NO_CMT
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA IN ('SILVER','GOLD') GROUP BY 1;
--   기대: NO_CMT = 0

-- ④ dbt 결과: ERROR 0 · SKIP 0 이어야 한다.
--   🔴 SKIP 은 무해하지 않다 — 상류 1건 실패가 모델 9 + 테스트 59 를 건너뛰게 만든 이력이 있다.
```

> 🔴 **재구축 후 기대값 인용 주의**: 각 스크립트에 적힌 행수·적중률은 **재구축 이전 측정치**다.
> BRONZE 를 재적재하면 값이 달라질 수 있다 — 어긋나면 원인 규명 전 **어느 쪽도 인용하지 말 것**(PROC-3 c).

---

> **관련 문서:** `04_운영 확인.md` (설계) · `05_ARCHITECTURE.md` (구조) · `01_환경_Role.md` (Role 정의) · `10_dbt_pipeline/` (dbt 배포·운영)
