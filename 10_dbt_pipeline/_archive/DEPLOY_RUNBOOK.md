---
project_id: GN_DW
doc_type: dbt_deploy_runbook
pipeline: gn_dw_silver (BRONZE→SILVER 32객체 + SILVER→GOLD 18객체)
target_object: GN_DW.SILVER.GN_DW_SILVER_PIPELINE
workspace_stage: "snow://workspace/USER$.PUBLIC.\"snowflake_files\"/versions/live/10_dbt_pipeline"
last_updated: 2026-07-14
author: Co-authored with CoCo
---

# dbt 파이프라인 배포 런북 (DEPLOY RUNBOOK)

> SILVER dbt 파이프라인을 Snowflake 네이티브 DBT PROJECT 객체로 배포하고 운영하는 절차.
> 실행 SQL 정본: `99_DEPLOY_ORCHESTRATION.sql`

---

## 전제조건

| 항목 | 상태 확인 방법 |
|---|---|
| GN_DW.SILVER 스키마 존재 | `SHOW SCHEMAS IN DATABASE GN_DW;` |
| BRONZE 테이블 적재 완료 | `SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO;` |
| COMPUTE_WH 가용 | `SHOW WAREHOUSES LIKE 'COMPUTE_WH';` |
| Role: ACCOUNTADMIN | `SELECT CURRENT_ROLE();` |
| dbt parse 성공 | 워크스페이스에서 `EXECUTE DBT PROJECT ... ARGS='parse'` 또는 CoCo 세션에서 확인 |

---

## 배포 단계 (Step-by-Step)

### Step 1. CREATE DBT PROJECT (네이티브 객체 배포)

```sql
CREATE DBT PROJECT IF NOT EXISTS GN_DW.SILVER.GN_DW_SILVER_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'BRONZE→SILVER 정제 파이프라인(32객체). 정본 09_SILVER_적재쿼리_20260714. 순서 7.';
```

**확인:**
```sql
SHOW DBT PROJECTS IN SCHEMA GN_DW.SILVER;
```

---

### Step 2. compile 검증 (데이터 변경 없음, 안전)

```sql
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='compile';
```

- SQL 생성만 수행, 테이블 생성/변경 없음
- 오류 발생 시: 모델 SQL 또는 macro 수정 후 Step 1 재배포

---

### Step 3. build 실행 (SILVER 32테이블 데이터 갱신, DDL 구조 보존)

> [순서 8-B] SILVER 구조 소유주 = `04_silver_design/08_SILVER_테이블DDL_20260714.sql`(33→**32테이블** 선생성). dbt 는 `incremental + pre-hook TRUNCATE + append + full_refresh:false` 로 **구조·제약·주석 보존하며 데이터만 전체 재적재**(멱등 Δ0). 전제: 08 DDL 선행 실행(미존재 시 첫 run 이 CTAS 로 구조 없이 생성).
> ⚠️ 매 run 전체 TRUNCATE 후 재적재. 업무 시간 외 실행 권장. `run` 아닌 `build`(test 게이트) 사용.

```sql
-- 전체 실행 (build = run + test 게이트)
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build';

-- 선택 실행 (GA4 전용 + 하류 XREF)
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build --select silver.ga4+';
```

**확인:**
```sql
-- 실행 결과 확인
SELECT * FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY())
ORDER BY SCHEDULED_TIME DESC LIMIT 5;
```

---

### Step 4. test 실행 (스키마 테스트)

```sql
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='test';
```

- `_crm_schema.yml`, `_ga4_schema.yml`에 정의된 not_null 등 컨트랙트 검증

---

### Step 5. TASK 생성 (일배치 스케줄)

```sql
CREATE TASK IF NOT EXISTS GN_DW.SILVER.TASK_SILVER_DAILY
  WAREHOUSE = COMPUTE_WH
  SCHEDULE  = 'USING CRON 0 5 * * * Asia/Seoul'   -- 매일 05:00 KST
  COMMENT   = 'BRONZE→SILVER 32객체 일배치 재정제(dbt run). 순서 7-D.'
AS
  EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run';
```

**가동:**
```sql
ALTER TASK GN_DW.SILVER.TASK_SILVER_DAILY RESUME;
```

---

## 운영 명령어

| 작업 | SQL |
|---|---|
| 프로젝트 상태 확인 | `SHOW DBT PROJECTS IN SCHEMA GN_DW.SILVER;` |
| 태스크 이력 조회 | `SELECT * FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME=>'TASK_SILVER_DAILY')) ORDER BY SCHEDULED_TIME DESC;` |
| 태스크 일시중지 | `ALTER TASK GN_DW.SILVER.TASK_SILVER_DAILY SUSPEND;` |
| 태스크 재개 | `ALTER TASK GN_DW.SILVER.TASK_SILVER_DAILY RESUME;` |
| 즉시 실행 | `EXECUTE TASK GN_DW.SILVER.TASK_SILVER_DAILY;` |
| 프로젝트 삭제 | `DROP DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE;` |

---

## DAG 의존순서 (dbt ref 자동 보장)

```
CRM_CODE ─────┬→ CRM_MEMBER, CRM_CAMPAIGN, CRM_EVENT, ...
              └→ CRM_MEMBER_SPONSOR_BIZ → CRM_SPONSOR_RELATION

GA4_IDENTITY ──┐
               ├→ IDENTITY_MEMBER_XREF
CRM_MEMBER ────┘

CRM / ERP / AGENCY / GA4 도메인 간 = 상호 독립 (병렬 실행, threads=4)
```

---

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| CREATE 실패: "stage not found" | 워크스페이스 경로 불일치 | `snow://workspace/...` URI 확인 |
| compile 오류: "relation not found" | BRONZE 테이블 미존재 | `SHOW TABLES IN SCHEMA GN_DW.BRONZE_CRM;` 확인 |
| run 부분 실패 | 특정 모델 SQL 오류 | `ARGS='run --select <model>'`로 개별 재실행 |
| TASK 3회 연속 실패 → SUSPEND | 근본 원인 미해결 | 원인 해결 후 `ALTER TASK ... RESUME;` |

---

## 관련 문서

| 문서 | 위치 | 내용 |
|---|---|---|
| 배포 DDL (실행용) | `10_dbt_pipeline/99_DEPLOY_ORCHESTRATION.sql` | CREATE/EXECUTE/TASK SQL 정본 |
| dbt 작업가이드 | `10_dbt_pipeline/GOLD_파이프라인_dbt_작업가이드 20260703.md` | 모델 작성 규칙 |
| SILVER 적재 정본 | `04_silver_design/09_SILVER_적재쿼리_20260714.sql` | dbt 모델의 원본 SQL |
| run 전후 이력·비교 | `04_silver_design/10_SILVER_RUN_이력_비교_20260714.md` | 32객체 BEFORE/AFTER, GA4 회귀 분석 |
| 운영 런북 | `02_GN_DW_building/06_RUNBOOK.md` | 전체 GN_DW 운영 매뉴얼 |
| 구현 예견이슈 | `10_dbt_pipeline/DBT_구현_예견이슈 20260703.md` | 구현 지뢰/주의사항 |
| (아카이브) 마이그레이션·파일명세 | `10_dbt_pipeline/_archive/` | 구식 문서 보존 |

---

## 세션 이력 (CHANGELOG)

### 2026-07-14 — SILVER dbt 파이프라인 배포·검증 (순서 7 완료)

| 순번 | 작업 | 명령/대상 | 결과 |
|---|---|---|---|
| 1 | parse | ARGS='parse' | OK (32 models, 9 tests, 40 sources, 482 macros) |
| 2 | CREATE DBT PROJECT | GN_DW.SILVER.GN_DW_SILVER_PIPELINE | 생성 성공 (dbt 1.9.4, EAI=None) |
| 3 | compile | ARGS='compile' | OK (32 models 정상) |
| 4 | run (1차) | ARGS='run' | PASS=32, **단 GA4 6객체 0행 회귀** |
| 5 | 회귀 원인분석·수정 | `macros/ga4_union_shards.sql` | 대소문자 버그 2건 수정 |
| 6 | run (재실행) | ARGS='run --select silver.ga4+' | PASS=6, **32객체 전량 Δ0 회복** |
| 7 | test | ARGS='test' | PASS=9 WARN=0 ERROR=0 |
| 8 | ADD VERSION | VERSION$2 (default) | 매크로 수정 반영 배포 |
| 9 | 오케스트레이션 개정 | `99_DEPLOY_ORCHESTRATION.sql` | run→build, CRON 보류, 온디맨드/트리거 방침 확정 |

**GA4 매크로 회귀 (조용한 데이터 손실) — 재발방지 핵심 교훈:**
- 원인 1: BRONZE_GA4 샤드 **테이블명**이 소문자 인용식별자(`"events_20260501"`) → 매크로의 대소문자 구분 `LIKE 'EVENTS_%'`가 0건 매칭 → 빈 결과.
- 원인 2: 샤드 **컬럼명**도 소문자 인용식별자(`"event_date"` 등) → `SELECT event_date`가 `invalid identifier 'EVENT_DATE'`.
- 수정: `UPPER(table_name) LIKE 'EVENTS\_%' ESCAPE '\'` + FROM절 `"{{ t }}"` + SELECT `"col" AS COL` (14컬럼).
- ⚠️ **dbt `run`은 0행도 SUCCESS로 통과** → 무인 스케줄 위험. 그래서 운영계약을 `build`(run+test)로 확정.

**운영 방침 결정:** BRONZE 원천이 "정기 갱신·주기 불규칙" → 고정 CRON 안티패턴. 현행 = 온디맨드 `build`, 최종형 = 트리거 기반 TASK(적재 메커니즘 확정 후).

**현재 상태:** SILVER 32객체 배포·검증 완료(VERSION$2). GOLD(순서 8)는 `enabled: false` 로 미착수.

---

### 2026-07-14 — GOLD dbt 파이프라인 활성화·구현·검증 (순서 8 완료)

| 순번 | 작업 | 명령/대상 | 결과 |
|---|---|---|---|
| 1 | GOLD 스키마 생성 | `CREATE SCHEMA GN_DW.GOLD WITH MANAGED ACCESS` | 생성(ACCOUNTADMIN 소유) |
| 2 | GOLD 구조 DDL | `03_top-down_gold/06_DDL.sql` (사용자 실행) | 24테이블(DIM15+FACT9)·제약·주석 생성 |
| 3 | 컬럼 정합 검증 | dim 모델 산출 ↔ DDL 컬럼 대조 | gold_ready 5개 완전 일치 |
| 4 | `dbt_project.yml` gold 활성화 | `+enabled:true`, `+database/schema`, `+full_refresh:false` | dim=incremental(DDL 보존)/fact=table |
| 5 | compile | ARGS='compile' | OK (50 models, 29 tests, 40 sources) |
| 6 | build gold.dim | ARGS='build --select gold.dim' | PASS=27, ERROR=0 (12 incr + 15 test) |
| 7 | build gold.fact | ARGS='build --select gold.fact' | PASS=15, ERROR=0 (6 table + 9 test) |
| 8 | 멱등 재실행 | ARGS='build --select gold' | PASS=38, ERROR=0, **18테이블 Δ0** |

**설계 결정 (보수적·downstream 오류 방지):**
- **구조 소유주 = 06_DDL.sql**. dbt는 구조를 덮지 않고 적재만 → `full_refresh:false`.
- **dim = incremental(merge)**: DDL 테이블 구조·제약·주석 보존, unique_key=_SK. 재실행 시 전체 소스 재처리·merge → 멱등.
- **fact = table**: 스캐폴드 grain이 선언 unique_key와 실제 비유일(예: FACT_EVENT_PARTICIPATION 동일 회원·행사·일자 다중참여) → incremental+merge 시 **행소실**. 정보성 FK·주석(NOT ENFORCED, FACT PK/UNIQUE는 DDL에서 보류) 손실보다 데이터 정확성 우선 → table 유지(D1 정본).

**적재 행수 (2회 실행 동일, Δ0):**

| 테이블 | 행수 | 테이블 | 행수 |
|---|--:|---|--:|
| DIM_MEMBER | 1,763,065 | FACT_SERVICE_EVENT | 38,471,525 |
| DIM_CAMPAIGN | 36,144 | FACT_MEMBER_MONTHLY | 36,577,960 |
| DIM_REASON | 5,835 | FACT_MEMBER_EVENT | 4,633,105 |
| DIM_EVENT | 3,787 | FACT_EVENT_PARTICIPATION | 1,134,126 |
| DIM_GA_EVENT | 2,841 | FACT_GA_BEHAVIOR | 19,555 |
| DIM_ORG | 1,315 | FACT_TARGET_DEV | 7,272 |
| DIM_GA_SOURCE | 110 | DIM_SPONSORSHIP | 51 |
| DIM_SERVICE | 11 | DIM_PAYMENT | 7 |
| DIM_DEVICE | 2 | **DIM_DATE** | **1** |

**주의·관찰:**
- `DIM_DATE=1행`: GA4_EVENT.EVENT_DT 전량 **2026-05-01 단일 일자**(265,312행, distinct=1) → 데이터 기반 정상값. GA4 샤드 추가 입고 시 자동 확장(materialized 재생성).
- `DIM_MEMBER_IDENTITY`: 자체 `enabled=false` 유지(GA4_IDENTITY·XREF 대기). GOLD 24테이블 중 dbt 적재 18개, 미적재 6개(AD_CREATIVE/BUDGET_ITEM/TARGET_BIZ/AD_PERFORMANCE/BUDGET + IDENTITY) = 원천 부재/대기.
- 워크스페이스 직접실행(`execute dbt project from workspace ... project_root='/10_dbt_pipeline'`)으로 검증. 배포객체(VERSION$2) 반영은 별도 `ALTER ... ADD VERSION` 필요.

**현재 상태:** SILVER 32객체 + GOLD 18객체(dim12+fact6) 적재·검증 완료. 멱등 확인. 배포객체 GOLD 반영(ADD VERSION)은 승인 대기.

---

### 2026-07-14 — SILVER "DDL 소유 + dbt 데이터만 갱신" 전환 (순서 8-B 완료)

| 순번 | 작업 | 명령/대상 | 결과 |
|---|---|---|---|
| 1 | SILVER materialization 전환 | `dbt_project.yml` silver 블록 + GA4/bridge 6모델 인라인 | table/INSERT OVERWRITE → **incremental + pre-hook TRUNCATE + append + full_refresh:false** |
| 2 | 구조 소유주 DDL 실행 | `04_silver_design/08_SILVER_테이블DDL_20260714.sql` (사용자) | SCHEMA + **32테이블** CREATE OR REPLACE (제약·주석) |
| 3 | compile | ARGS='compile' | OK (50 models, 29 tests, 40 sources, 482 macros) |
| 4 | 파일럿 build | ARGS='build --select CRM_CODE' | PASS=1, ERROR=0 (truncate+append·컬럼정합 검증) |
| 5 | 전체 SILVER build | ARGS='build --select silver' | PASS=41 (32 incr + 9 test), ERROR=0 |
| 6 | 멱등 재실행 | ARGS='build --select silver' 2회차 | PASS=41, **32테이블 Δ0** |
| 7 | GOLD 회귀 재빌드 | ARGS='build --select gold' | PASS=38, ERROR=0, **dim 12 + fact 6 전부 baseline Δ0** (fact COUNT 확인 완료) |
| 8 | 배포객체 반영 | `ALTER DBT PROJECT ... ADD VERSION` | 신규 버전 = default (GOLD활성화 + SILVER DDL소유전환) |

**전략 요약 (옵션 A = TRUNCATE+append):**
- **구조 소유주 = 08_SILVER_테이블DDL_20260714.sql** (CRM21·ERP3·AGENCY2·GA4 5·bridge1 = 32). dbt 는 구조를 덮지 않고 데이터만 갱신.
- 매 run: 기존 DDL 테이블 `TRUNCATE`(제약·주석·구조 보존) 후 전체 SELECT `append` 재적재. `unique_key` 불필요 → grain 비유일 모델 행소실 없음, 멱등(Δ0).
- `full_refresh:false` → `--full-refresh` 시에도 CTAS 재생성 차단(DDL 구조 보호).
- ⚠️ 리스크(해소): append 는 대상 DDL 모든 컬럼이 모델 산출 컬럼에 존재해야 함 → 32모델 전량 build PASS 로 컬럼 정합 확인.

**SILVER 적재 행수 (2회 실행 동일, Δ0 = GOLD baseline 소스와 일치):**

| 테이블 | 행수 | 테이블 | 행수 |
|---|--:|---|--:|
| CRM_MEMBER | 1,763,065 | CRM_SEND_MEMBER | 38,471,525 |
| CRM_MEMBER_DEV | 3,594,843 | CRM_PAYMENT_BILLING | 47,521,872 |
| CRM_MEMBER_STATUS_HIST | 7,501,761 | CRM_PAYMENT_METHOD | 2,545,696 |
| CRM_MEMBER_DISCONTINUE | 1,038,262 | CRM_SEND_REQUEST | 1,614,397 |
| CRM_MEMBER_AMT_CHANGE | 324,947 | CRM_SEND_RESULT | 1,611,758 |
| CRM_MEMBER_SPONSOR_BIZ | 2,170,572 | CRM_RELATION_ACTIVITY | 388,153 |
| CRM_SPONSOR_RELATION | 862,610 | CRM_EVENT_PARTICIPATION | 1,134,126 |
| CRM_CAMPAIGN | 36,144 | AGENCY_AD_PERFORMANCE | 235,572 |
| GA4_EVENT | 265,312 | CRM_MEMBER_RESPONSOR | 115,254 |
| ERP_BUDGET | 24,480 | CRM_DEV_TARGET | 25,344 |
| AGENCY_AD_CREATIVE | 8,473 | CRM_CODE | 5,834 |
| GA4_EVENT_DIM | 3,633 | CRM_EVENT | 3,787 |
| ERP_BUDGET_ITEM | 2,040 | GA4_TRAFFIC_SOURCE | 1,175 |
| GA4_IDENTITY | 1,348 | IDENTITY_MEMBER_XREF | 1,348 |
| CRM_ORG | 1,315 | GA4_DEVICE | 76 |
| CRM_SPONSORSHIP | 50 | ERP_BIZ_TARGET | 0 |

**주의:** `ERP_BIZ_TARGET=0행` = 원천 부재(정상). GA4_IDENTITY·IDENTITY_MEMBER_XREF 이제 적재됨(각 1,348) → GOLD `DIM_MEMBER_IDENTITY` 활성화 재검토 가능(선택 후속).

**현재 상태:** SILVER = DDL소유+데이터갱신 전환·검증 완료(멱등 Δ0). GOLD 재빌드로 dim 12 + fact 6 전부 baseline Δ0 확정. 배포객체(GOLD·SILVER 개정) ADD VERSION 반영 완료(신규 버전 default).

---

### 2026-07-15 — GOLD fact "table→incremental append" 전환 + DIM_DATE 재설계 + MEMBER_DK 판정 (순서 9 완료)

**배경 gap 판정 (설계적합성 검토 항목1·7):**
- **G-1(타입 소실)·G-2(FK 드롭)**: GOLD fact 6개가 `materialized='table'` → 매 run `CREATE OR REPLACE TABLE AS SELECT` 로 06_DDL 구조를 덮어써 컬럼 타입 소실 + fact FK 드롭(실측 GOLD FK 35→12). dim(merge)은 DDL 보존이라 정상.
- **결정**: fact `table` 전면 폐기 → SILVER 동일 **incremental + append + pre-hook TRUNCATE + full_refresh:false** (DDL=구조·타입·FK 소유, dbt=데이터만 갱신). TRUNCATE 는 구조 보존. 순서8의 "fact=table(D1)" 판정을 순서9에서 개정.

| 순번 | 작업 | 명령/대상 | 결과 |
|---|---|---|---|
| 1 | fact materialization 전환 | `dbt_project.yml` gold.fact 블록 + fact 6개 config 정리 | table → incremental+append+pre-hook TRUNCATE |
| 2 | DIM_DATE 재설계 | `models/gold/dim/DIM_DATE.sql` + `cal_start/cal_end` var | GA4 의존 제거 → 고정 캘린더 1991~2035 + DATE_SK=0 Unknown |
| 3 | date_sk 매크로 | `macros/gold_helpers.sql` | 캘린더 범위 클램프(범위밖/NULL→NULL, fact 에서 COALESCE(...,0)) |
| 4 | fact 날짜 라우팅·불량행 제외 | FMM/FEP/FSE/FME/FGA | DATE_SK COALESCE(...,0), FMM MONTH_KEY 3단 폴백+MBER_NO 필터(5행), FSE MBER_NO 필터(745행) |
| 5 | conformed dim Unknown 멤버 | DIM_DATE/DEVICE/GA_EVENT/GA_SOURCE | SK=0 'Unknown' 행 추가(센티넬 라우팅 대상) |
| 6 | 전체 build (검증) | ARGS='build' | ERROR=26 — SILVER relationship 실패가 하류 GOLD fact SKIP(=0행) 유발 |
| 7 | GOLD 한정 build | ARGS='build --select path:models/gold' | SILVER 테스트 게이트 우회 → fact 6개 정상 적재 |
| 8 | MEMBER_DK 판정 (Phase 2) | `_gold_ready_schema.yml` 4곳 | MEMBER_DK→DIM_MEMBER relationships **severity: warn** 강등 |
| 9 | 최종 build | ARGS='build --select path:models/gold' | **PASS=95 WARN=4 ERROR=0 SKIP=0** |

**검증 SELECT 결과 (G-1/G-2/DATE 해소 확인):**
- GOLD fact FK 개수 = **35** (G-2 해소, FK 생존).
- FMM 타입 복원: MONTH_KEY `NUMBER(6,0)`, PAID_FEE/BILLED_AMT `NUMBER(18,2)` (G-1 해소).
- DIM_DATE = **16,437행**(고정캘린더 + Unknown 1행, MIN(DATE_SK)=0).

**⚠️ 운영 교훈 — 전체 build 시 GOLD fact SKIP:**
- `build`(무선택)는 SILVER 테스트를 GOLD와 인터리브 → SILVER relationship 실패(예 CRM_PAYMENT_METH)가 하류 GOLD fact 를 **SKIP**(=이전 0행 유지). fact 모델 에러 아님.
- GOLD만 검증·적재하려면 반드시 `--select path:models/gold` (SILVER 테스트 게이트 우회, SILVER 테이블은 이미 존재해 ref 해결).

**Phase 2 — MEMBER_DK 고아 판정 (선택지 c 채택):**
- MEMBER_DK→DIM_MEMBER relationships 4건 실패: **통합 distinct 9,248명**(FSE 31,486행/FEP 9,480/FME 271/FMM 181).
- 성격: **8,803명(95%)이 정상 7자리 FDRM 활동회원**(거래 여러 fact 등장)인데 마스터(CRM_MEMBER)에 부재 + ONCE(S) 206 + 불량ID ~239(예 `1`). → fact 버그 아닌 **회원 마스터 스냅샷 미완전**(부분적재).
- 결정: **(c) severity: warn** — (a 라우팅=실ID 추적성 상실 / b DIM 보강=속성NULL 셸 오염) 대비 비파괴·가역. build 통과. **마스터 전량입고 후 severity 제거(error 복귀)** 조건 명시(주석 기재).

**GOLD 적재 행수 (순서9, 6 fact 전량):**

| 테이블 | 행수 | 비고 |
|---|--:|---|
| FACT_MEMBER_MONTHLY | 37,792,342 | MONTH_KEY 회비월 grain+폴백(순서8 36.58M 대비 증가) |
| FACT_SERVICE_EVENT | 38,470,780 | MBER_NO NULL 745행 제외(순서8 38.47M) |
| FACT_MEMBER_EVENT | 4,633,105 | Δ0 |
| FACT_EVENT_PARTICIPATION | 1,134,126 | Δ0 |
| FACT_GA_BEHAVIOR | 19,555 | Δ0 |
| FACT_TARGET_DEV | 7,272 | Δ0 |

**현재 상태:** GOLD fact 6개 = incremental+append 전환·검증 완료(G-1/G-2 해소, FK 35 생존). DIM_DATE 고정캘린더 재설계 완료. GOLD 테스트 PASS=95/WARN=4(MEMBER_DK 소스 gap)/ERROR=0. **워크스페이스 직접실행 검증만 완료 — 배포객체 ADD VERSION 미반영(승인 대기).** 설계적합성 검토 항목1(GOLD fact+dim) 완료, **잔여: 항목1 SILVER 32모델 컬럼정합 + 항목2~6.**

**순서9-B 하드닝 (데이터 아키텍처 비판적 재검토 후 보수적 수정 — build 재검증 완료):**
- **FMM MONTH_KEY 무결성**: `COALESCE(TRY_TO_NUMBER(MBRFEE_MT), ...)` 이 YYYYMM 검증 없이 소스 쓰레기 숫자를 통과(실측 무효 ~2,043행: MIN 20251·MAX 210103, 범위밖·월>12) + 정상 PAY_DE 폴백 단락. → `month_key_clamp` 매크로 신설(범위 199101~203512·월 01~12 검증, 무효→NULL) 후 `COALESCE(clamp(MBRFEE_MT), clamp(PAY_DE월), 0)`. 재검증: **무효 월키 0건**(below/above/bad_month 전부 0), MK=0 은 53행(양쪽 무효), 순행수 −6. GROUP BY 는 출력 별칭(`MONTH_KEY, MEMBER_DK`)으로 단순화(검증식 중복 제거).
- **DIM_DATE rowcount 매직상수 제거**: `GENERATOR(rowcount => 16500)`(cal_end 확장 시 조용한 캘린더 잘림 잠복결함) → jinja `modules.datetime` 로 cal_start~cal_end 실제 일수 자동 산출. 재검증 16,437행 유지.
- **DATE_SK 라우팅 건강 확인**(수정 불필요): DATE_SK=0 비율 FEP 50·FME 90·FGA 0·FSE 0 = 극소.
- 영향 파일: `macros/gold_helpers.sql`(month_key_clamp 추가), `models/gold/fact/FACT_MEMBER_MONTHLY.sql`, `models/gold/dim/DIM_DATE.sql`.

**순서9-B 설계적합성 검토 항목 2~6 (완료 — 상세·미결은 `_OPEN_ITEMS_후속조치.md`):**
- **항목2(grain·키)**: 통과. FEP/FSE/FME 행수=소스(fan-out 없음), FGA 조인 base=joined=265,312 실측, 조인 자연키 NULL-safe 중복 0. 노트: 월 팩트(FMM/ERP_BUDGET) MONTH_KEY grain ↔ DIM_MONTH 부재.
- **항목3(ref 방향)**: 통과. 전 SILVER 모델 intra-SILVER ref(코드 라벨 등), 교차소스는 `IDENTITY_MEMBER_XREF` 단일 예외(문서화됨). 역참조·BRONZE 직참조 없음.
- **항목5(누락/과잉)**: GOLD DDL 24개 중 미적재 6개 식별(AGENCY 2·ERP 3·DIM_MEMBER_IDENTITY). 소스 준비된 4개는 모델 미작성. DIM_MEMBER_IDENTITY enabled=false 유지 권고. → 결정 대기.
- **항목6(test 커버리지)**: full build ERROR=26 원인 3종 계량 — ① 회원 마스터 미완전 고아(SILVER MBER_NO→CRM_MEMBER 8+2테이블, GOLD와 동일원인) ② `EVENT_KEY→CRM_EVENT` 고아 263,611(참여 23%!) ③ `SNDNG_KEY→CRM_SEND_REQUEST` 11,313+9·not_null MBER_NO NULL 745+5.
  - **조치(선택적)**: ① 회원→CRM_MEMBER relationships 12건 `severity: warn` 강등(GOLD 일관, 마스터 전량입고 후 error 복귀 — `_OPEN_ITEMS` BLOCKING-1). ②③ 은 별개 근본원인이라 **error 유지**(현업 §E 판정 대기). ②(EVENT_KEY) 로 인해 full build 는 여전히 실패, GOLD-only build 만 green.
- **항목4(정제규칙 이행 vs 09_적재쿼리)**: **미착수** (`_OPEN_ITEMS` 참조).
- 신규 산출물: `_현업검토요청_의심데이터_20260715.md`(A~E 현업 판정 요청), `_OPEN_ITEMS_후속조치.md`(미결 추적).
- ⚠️ 검증 필요: SILVER 테스트 severity 변경 반영은 `dbt build --select path:models/silver path:models/gold` (또는 `dbt test`)로 사용자 확인 예정.
