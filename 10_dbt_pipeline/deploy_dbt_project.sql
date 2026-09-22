-- <!-- LLM-METADATA
-- doc_id: GN_DW_DEPLOY_DBT_PROJECT_SQL
-- doc_role: Snowflake Native DBT PROJECT (GN_DW.OPS.DW_PIPELINE) 배포, 실행, 스냅샷, 빌드 및 스케줄링 운영 정본 SQL
-- project: GN_DW (굿네이버스)
-- updated: 2026-09-09
-- updated_by: TRIALADMIN
-- index: 20_issue/00_INDEX_이슈원장.md
-- source_refs:
--   - 10_dbt_pipeline/00_배포운영_통합_20260715.md
--   - 06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md
--   - 06_snapshot/02_스냅샷_파이프라인_구축_작업계획.md
-- END-METADATA -->

-- ============================================================================
-- [GN_DW] Snowflake Native dbt Project 배포 및 운영 런북 (정본)
--
-- 📌 핵심 운영 원칙 & RBAC 권한 분리:
--   1. 프로젝트 위치: GN_DW.OPS.DW_PIPELINE (운영/툴링 스키마)
--   2. 역할 분리 (최소 권한 원칙):
--      - 배포/관리/스케줄링: GN_DW_ADMIN (DBT PROJECT 소유자, DDL/Task 관리)
--      - 일상 실행/정제/검증: GN_DW_ENGINEER (파이프라인 실행자, DML/Test 수행)
--   3. 웨어하우스: GN_DW_DEV_WH(개발·검증) · GN_DW_ETL_WH(배치)
--   4. 구조 소유권: SILVER/GOLD 테이블 DDL은 SQL DDL이 소유하며, dbt는 데이터 정제만 담당(DDL 보존).
--   5. 실행 순서: parse ➔ compile ➔ snapshot (SCD2 누적) ➔ build (SILVER/GOLD 정제+테스트)
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 0 — 사전 환경 및 세션 확인 (안전, 읽기 전용)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_ROLE() AS ROLE, CURRENT_WAREHOUSE() AS WAREHOUSE;

-- OPS 스키마 및 기존 DBT PROJECT 확인
SHOW SCHEMAS IN DATABASE GN_DW;
SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1 — DBT PROJECT 배포 및 버전 관리 (관리자 역할: GN_DW_ADMIN)
-- ─────────────────────────────────────────────────────────────────────────────
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- (1) OPS 스키마 보장 및 권한 (필요 시)
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 ETL 운영/툴링 객체 전용 스키마';

-- (2-A) [최초 1회만] DBT PROJECT 신규 생성 (VERSION$1)
-- 최초 배포 후 '08_After_Deploy_DBT.sql' 돌리고 ENGINEER권한으로 BUILD
-- CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  -- FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

-- (2-B) [코드 수정 시] 신규 버전 추가 배포 (VERSION$N+1 자동 증가 및 default 승격)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION SILVER_BIGQUERY_EXPAND_20260922121910
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET
  COMMENT = 'BRONZE→SILVER→GOLD. [20260922] SILVER스키마 데이터량 제한 해제';

-- (3) 배포된 버전 상태 확인
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;
DESCRIBE DBT PROJECT GN_DW.OPS.DW_PIPELINE;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2 — 문법 및 컴파일 검증 (엔지니어 역할: GN_DW_ENGINEER)
-- ─────────────────────────────────────────────────────────────────────────────
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_DEV_WH;

-- 모델, 매크로, 스냅샷, yml 문법 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';

-- SQL 렌더링 및 참조 무결성 컴파일 검증
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3 — 파이프라인 실행 (엔지니어 역할: GN_DW_ENGINEER)
-- ─────────────────────────────────────────────────────────────────────────────
-- ⚠️ 실행 순서: 스냅샷을 먼저 실행하여 원천 마스터의 최신 변경분을 보존한 후, build를 수행합니다.
-- 최초 배포 후 '08_After_Deploy_DBT.sql' 돌리고 ENGINEER권한으로 BUILD
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_DEV_WH;

-- [3-1] 마스터 스냅샷 실행 (BRONZE 마스터 SCD Type 2 이력 누적)
-- 전체 스냅샷 실행:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- 특정 티어 또는 개별 스냅샷만 실행 시:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot --select snp_crm_tm_cm_cmpgn_mng snp_crm_tm_cm_dept_info snp_crm_tm_cm_spnsr_bsns_info';

-- [3-2] SILVER / GOLD 정제 및 테스트 실행 (build = run + test 게이트)
-- 전체 빌드:
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- build 실패시 수정 후 실패지점부터 이어서 진행
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';

-- 도메인/레이어별 부분 빌드:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select gold.dim';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select gold.fact';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3-3 — 🔴🔴 [필수] 재배포 후 BIGQUERY 체인 일자 수 확인 (엔지니어 역할)
-- ─────────────────────────────────────────────────────────────────────────────
-- 🔴🔴 왜 이 단계가 필수인가 (2026-09-22 O178 · 실사고 규명)
--   BIGQUERY 파생(BIGQUERY_BASIC·BIGQUERY_EVENT·FACT_BIGQUERY_BEHAVIOR)은 O177 부터
--   **롤링 윈도우 증분**이다 — 매 run 이 다시 만드는 구간은 [오늘 - bigquery_lookback_days, ∞) 뿐이고
--   창 밖 과거는 손대지 않는다(macros/bigquery_range_predicate.sql · 개명 예정).
--   ⇒ 🔴 **재배포로 SILVER/GOLD 가 빈 상태가 되면 그 빈 상태가 영구히 남는다.**
--      창에 원천 데이터가 없으면 모델은 SUCCESS 로 끝나고 **행수만 조용히 0** 이다.
--
--   실사고(2026-09-21 20:39~20:57 · 쿼리이력으로 규명):
--     ㉠ 재배포로 테이블이 비었다(그 시점 DELETE 가 0행을 지웠다 = 이미 비어 있었다)
--     ㉡ **구 버전**(6월 고정창) 빌드가 먼저 돌아 3일치 1,299,412행만 채웠다
--     ㉢ **신 버전** 롤링 윈도우는 창 [2026-09-19, ∞) 에 원천이 없어 **정상 no-op** 했다
--        (원천 최대 일자가 2026-09-14 였다)
--     ⇒ 하류가 33일 → **3일치로 회귀**했고 **ERROR 는 0** 이었다. 완전 무증상이다.
--   🟢 판정식 = **증분 파이프라인에서는 「배포 순서」가 데이터 범위를 결정한다.**
--      전량 TRUNCATE 시절에는 배포 순서가 데이터에 영향을 주지 않았다 —
--      증분화가 **배포 절차를 데이터 정합성의 일부로** 만들었다.
--
-- 🔴 아래 2개 쿼리는 **재배포 + build 직후 매번** 돌린다. Step 4 의 일일 배치 Task 를
--    RESUME 하기 **전에** 반드시 통과시킬 것 — 자동화되면 이 사고가 무인으로 반복된다.
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_DEV_WH;

-- [3-3-a] 원천 ↔ 하류 **일자 수 대조** (기대 = 세 값이 모두 같다)
--   🔴 행수가 아니라 **일자 수**를 본다 — 일자 단위 창이 누락의 단위이기 때문이다.
--   ⚠️ 이 개발 계정의 원천은 월 1일씩 샘플링돼 들어온다(운영 원천은 전일자다) ⇒
--      「33」 같은 절대값을 기대값으로 박지 말고 **원천과 같은지**를 본다.
SELECT 'SRC  BIGQUERY_REFINED_DATA' AS LAYER,
       COUNT(DISTINCT TRY_TO_DATE(EVENT_DATE, 'YYYYMMDD')) AS DAYS_,
       COUNT(*)                                           AS ROWS_
  FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
 WHERE EVENT_DATE IS NOT NULL
UNION ALL
SELECT 'SILVER BIGQUERY_BASIC', COUNT(DISTINCT EVENT_DT), COUNT(*)
  FROM GN_DW.SILVER.BIGQUERY_BASIC
UNION ALL
SELECT 'SILVER BIGQUERY_EVENT', COUNT(DISTINCT EVENT_DT), COUNT(*)
  FROM GN_DW.SILVER.BIGQUERY_EVENT
UNION ALL
SELECT 'GOLD  FACT_BIGQUERY_BEHAVIOR', COUNT(DISTINCT DATE_SK), COUNT(*)
  FROM GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR
ORDER BY 1;

-- [3-3-b] 감시 테이블 확인 (기대 = 전건 0행)
--   🔴 WARN_BIGQUERY_LOAD_GAP(개명 예정 = WARN_BIGQUERY_LOAD_GAP) 이 **양방향** 감시다:
--      DIRECTION='SRC_ONLY'  = 원천에 있고 하류에 없다(누락 · 위 사고가 여기 걸렸다 · 30행)
--      DIRECTION='DW_ONLY'   = 하류에 있고 원천에 없다(고아 · 창 밖이라 영구 잔존)
--      DIRECTION='BAD_DATE_FORMAT' = 원천 EVENT_DATE 가 YYYYMMDD 로 파싱되지 않는다
SELECT 'WARN_BIGQUERY_LOAD_GAP' AS MONITOR, COUNT(*) AS ROWS_ FROM GN_DW.OPS.WARN_BIGQUERY_LOAD_GAP
UNION ALL
SELECT 'WARN_GOLD_FACT_BIGQUERY_DATE_SK_ZERO', COUNT(*) FROM GN_DW.OPS.WARN_GOLD_FACT_BIGQUERY_DATE_SK_ZERO
UNION ALL
SELECT 'WARN_BIGQUERY_NULL_USER_PSEUDO_ID', COUNT(*) FROM GN_DW.OPS.WARN_BIGQUERY_NULL_USER_PSEUDO_ID
ORDER BY 1;

-- 🔴 [3-3-a] 일자 수가 원천보다 적거나 [3-3-b] 가 0행이 아니면 **여기서 멈춰라.**
--    복구 경로는 **ⓐ 수동 백필 하나뿐**이다(롤링 윈도우는 창 밖을 건드리지 않고,
--    SILVER·GOLD 는 full_refresh:false 라 --full-refresh 도 막혀 있다):
--      ㉠ dbt_project.yml vars 의 `bigquery_dt_ranges` 주석을 **일시적으로 풀고** 구간을 적는다
--         (전량이면 ['2024-01-01', '9999-12-31'] · 🔴 하한은 원천 최소일과 대조할 것)
--      ㉡ ALTER DBT PROJECT … ADD VERSION 으로 **재배포**한다(파일만 고쳐도 반영되지 않는다)
--      ㉢ EXECUTE DBT PROJECT … ARGS='build --select BIGQUERY_BASIC+'
--      ㉣ 🔴 **주석을 다시 잠그고 재배포한다** — 상주시키면 이중 샘플링이 재발하고
--         일일 배치가 매일 전 기간을 재적재한다(O178 이 이 재잠금 반영을 별도 검증했다)
--      ㉤ 위 [3-3-a]·[3-3-b] 를 다시 돌려 대사한다
--    🔴🔴 `--vars` 로 오버라이드하지 마라 — 이 환경에서 **조용히 무시된다**(실측 O177).
--    🟢 실증(O178) = 전량 백필로 3일치 → 33일 10,332,737행 복구 · WARN 30행 → 0행.



-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 일일 스케줄 자동화 DAG (관리자 역할: GN_DW_ADMIN)
-- ─────────────────────────────────────────────────────────────────────────────
-- 📌 일일 배치 순서:
--   1. [선행 루트 Task (05:30 KST)]: dbt snapshot 실행 (원천 마스터 이력 누적)
--   2. [후속 자식 Task (완료 즉시)]: dbt build 실행 (SILVER/GOLD 전체 정제 및 테스트)
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- (A) 선행 루트 태스크 (스냅샷):
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   WAREHOUSE = GN_DW_DEV_WH
--   SCHEDULE = 'USING CRON 30 5 * * * Asia/Seoul'
--   COMMENT = 'dbt snapshot 일일 실행 (마스터 SCD Type 2 변경분 누적)'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='snapshot';

-- (B) 후속 차일드 태스크 (빌드):
-- CREATE OR ALTER TASK GN_DW.OPS.TASK_DW_BUILD_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   AFTER GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY
--   COMMENT = '스냅샷 완료 후 DW_PIPELINE 일일 build(run+test) 자동 실행'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- (C) 태스크 체인 활성화 (자식 태스크 먼저 RESUME ➔ 루트 태스크 RESUME):
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_BUILD_DAILY RESUME;
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY RESUME;

-- (D) 태스크 상태 확인 및 일시 중지:
SHOW TASKS LIKE '%DW_%' IN SCHEMA GN_DW.OPS;
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY SUSPEND;
ALTER TASK IF EXISTS GN_DW.OPS.TASK_DW_BUILD_DAILY SUSPEND;


-- ─────────────────────────────────────────────────────────────────────────────
-- Step 5 — 하류 SERVING 계층 및 Cortex Agent 연계 (관리자 역할: GN_DW_ADMIN)
-- ─────────────────────────────────────────────────────────────────────────────
-- 📌 01_환경 Role.md 원칙: GN_DW DB·전 스키마·테이블/뷰·SV/Agent 소유 = GN_DW_ADMIN 소유
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [5-1] Semantic View 배포 및 비즈니스 모델링
-- 05_SV-Agent_ai/05_1~05_10_SV_DDL_*.sql  ➔ SEMANTIC VIEW 10종 배포 및 검증

-- [5-2] Cortex Agent 객체 생성 및 서비스 스펙 등록
-- 05_SV-Agent_ai/09_1_AGENT_생성.sql     ➔ Cortex Agent 객체 생성
-- 05_SV-Agent_ai/09_2_AGENT_버전업.sql   ➔ Cortex Agent 스펙(Instruction/도구) 배포
