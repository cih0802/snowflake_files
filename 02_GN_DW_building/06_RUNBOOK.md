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

```sql
-- star schema 컬럼 변경 시: 03_top-down_gold/06_DDL.sql 재실행 후 dbt build
-- (예: FMM HAS_BILLING 추가처럼 스키마 변경이 선행되는 경우)
```

> ⛔ 예측(Forecast) 파이프라인은 제외 결정(2026-07-10)으로 미운영.

### 3.4 데이터 품질 검증 (수동)

```sql
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='test';
-- not_null/unique/relationships 결과 확인. relationships=warn은 관측용.
```

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

> **관련 문서:** `04_운영 확인.md` (설계) · `05_ARCHITECTURE.md` (구조) · `01_환경_Role.md` (Role 정의) · `10_dbt_pipeline/` (dbt 배포·운영)
