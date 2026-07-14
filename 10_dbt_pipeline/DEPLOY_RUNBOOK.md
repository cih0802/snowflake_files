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
