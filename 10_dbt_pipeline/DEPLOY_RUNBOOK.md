---
project_id: GN_DW
doc_type: dbt_deploy_runbook
pipeline: gn_dw_silver (BRONZE→SILVER 32객체)
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

### Step 3. run 실행 (SILVER 32테이블 재생성)

> ⚠️ INSERT OVERWRITE 멱등이나 전체 테이블 재작성. 업무 시간 외 실행 권장.

```sql
-- 전체 실행
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run';

-- 선택 실행 (GA4 전용 + 하류 XREF)
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='run --select silver.ga4+';
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
