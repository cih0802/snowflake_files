-- GN_DW dbt PROJECT 최초 생성 (계정 이전 KD03246 후 재배포) — 정본 위치 GN_DW.OPS.DW_PIPELINE
-- Co-authored with CoCo

-- ============================================================================
-- 근거: 10_dbt_pipeline/00_배포운영_통합_20260715.md §1 (정본, 구 _archive/99 대체)
--   · 프로젝트 배치 = 운영/툴링 스키마 GN_DW.OPS (데이터레이어 SILVER/GOLD와 분리)
--   · 프로젝트명 = DW_PIPELINE (구 계정 동일: GN_DW.OPS.DW_PIPELINE)
--
-- ⚠️ 계정 이력: cs94293(구) → **KD03246(현재, TRIALADMIN)**. 문서 다수가 아직 cs94293 기준.
--    본 파일은 2026-07-29 KD03246 실측 기준으로 갱신됨.
--
-- ─── 사전조건 (2026-07-29 KD03246 실측) ─────────────────────────────────────
--   1. ✅ GN_DW.OPS 스키마 존재 (comment='ETL 운영 인프라 — dbt 프로젝트(DBT PROJECT DW_PIPELINE)')
--   2. ✅ 워크스페이스 10_dbt_pipeline/ 에 dbt_project.yml + models **77개** 존재
--         SILVER 38 + GOLD 39(dim 15 + fact 12 + wide 12)
--         ※ 구 문서의 "SILVER 32 + GOLD 33 = 65" 는 폐기 — 순서9 AGENCY 위성팩트 분리
--           (FAD_D·FAD_B·FAD_BC) + WIDE 12종 확장 반영분
--   3. ✅ RBAC 역할 6종 존재 — GN_DW_ADMIN·ENGINEER·ANALYST·VIEWER·LOADER·SERVICE
--   4. ✅ 웨어하우스 3종 존재 — GN_DW_ETL_WH(S)·GN_DW_DEV_WH(XS)·GN_DW_ANALYTICS_WH(M)
--   5. ✅ SERVING 스키마 존재
--   6. ❌ **SERVING helper 뷰 미생성 (객체 0개)** — DIM_MONTH·DIM_MEMBER_CURRENT·FACT_AD_COMBINED
--         → dbt 배포와 **무관**(dbt 는 SILVER/GOLD 만 소유). 단 SV/Agent 는 이 뷰 없이는 실패.
--         해소: 05_SV-Agent_ai/02_SERVING_setup.sql  또는
--               02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql §E+§G  → 그 다음 05_SV_DDL.sql
--   7. ✅ SILVER 38 / GOLD 27테이블+WIDE 12뷰 **이미 배포·적재 완료**
--         (FACT_MEMBER_MONTHLY 40,054,883 · FACT_SERVICE_EVENT 38,470,780 · FACT_TARGET_BIZ 0행=입고대기)
--         → 즉 워크스페이스 dbt build 는 이미 성공. 본 파일은 **거버넌스 오브젝트 등록**이 목적.
--   8. ❌ **DBT PROJECT 오브젝트 미존재** (SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS → 0행) ← 본 파일이 해결
--
-- 주의: 신규 계정이므로 versions/live = 최신 워크스페이스 코드 → CREATE 시 VERSION$1 이 곧 최신.
--       구 계정의 VERSION 드리프트 이슈 무관.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 참고 — Snowsight UI(Connect 메뉴) ↔ SQL 대응 (이 문서로 전부 대체 가능)
-- ─────────────────────────────────────────────────────────────────────────────
-- 워크스페이스 우측 상단 Connect 메뉴의 각 항목은 아래 SQL과 1:1 대응:
--   · Deploy dbt project(신규)      = CREATE DBT PROJECT ... FROM '.../versions/live'   → Step 1
--   · Existing dbt deployment(버전+) = ALTER DBT PROJECT ... ADD VERSION FROM '...'      → Step 3 하단
--   · Redeploy dbt project           = ALTER DBT PROJECT ... ADD VERSION (버튼형)         → Step 3 하단
--   · Create schedule                = CREATE TASK ... AS EXECUTE DBT PROJECT ...         → Step 4
--   · View project / View schedules  = SHOW DBT PROJECTS / SHOW TASKS + 오브젝트 탐색기   → Step 1 SHOW문
-- 차이(딱 하나): UI "Connect" 는 위 오브젝트 생성 외에 워크스페이스↔배포오브젝트 UI 연결(편의버튼)만
--   추가로 만든다. 이는 Snowflake 오브젝트가 아니라 UI 편의기능 → SQL 배포 후 UI를 붙이고 싶으면
--   Connect » Existing dbt deployment 에서 GN_DW.OPS.DW_PIPELINE 선택(중복 생성 아님).

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 0 — 사전조건 재확인 (읽기 전용, 안전)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_ROLE() AS ROLE;   -- 기대: KD03246

-- 레이어별 객체 수 (기대: SILVER 38 BASE / GOLD 27 BASE + 12 VIEW / SERVING 0 ← helper뷰 미배포)
SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*) AS CNT
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('SILVER', 'GOLD', 'SERVING')
GROUP BY 1, 2
ORDER BY 1, 2;

SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;   -- 기대: 0행(미존재) → Step 1 진행

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1 — CREATE (최초 배포) : VERSION$1 자동 default
-- ─────────────────────────────────────────────────────────────────────────────
-- OPS 스키마는 이미 존재(2026-07-28 생성) → 아래는 멱등 no-op.
--   ※ IF NOT EXISTS 이므로 기존 COMMENT('ETL 운영 인프라 — dbt 프로젝트…')는 덮이지 않음.
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 운영/툴링 객체 전용 (데이터 레이어 아님)';

-- CREATE DBT PROJECT 권한 (신 계정 실측: GN_DW_ADMIN 에 미부여 → ACCOUNTADMIN 이 선부여)
GRANT CREATE DBT PROJECT ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ADMIN;

-- 소유자는 GN_DW_ADMIN 으로 통일(GOLD/SILVER·SERVING 소유자와 동일 → grant 파편화 방지).
--   ACCOUNTADMIN 으로 만들면 05_SV-Agent_ai/13 의 owner 불일치 이슈가 재현됨.
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'BRONZE→SILVER 38 + SILVER→GOLD 27(dim 15 + fact 12) + WIDE VIEW 12 = 77 models. 정본 09_SILVER_적재쿼리_20260714 / 03_top-down_gold/06_DDL.';

SHOW DBT PROJECTS IN SCHEMA GN_DW.OPS;
SHOW VERSIONS IN DBT PROJECT GN_DW.OPS.DW_PIPELINE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2 — 검증 (테이블 불변, 안전 — 데이터 변경 없음)
-- ─────────────────────────────────────────────────────────────────────────────
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='parse';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile';

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3 — 적재 (준비되면 주석 해제) : run 금지·build 사용(run+test 게이트, R2)
-- ─────────────────────────────────────────────────────────────────────────────
-- ⚠️ SILVER/GOLD 는 이미 적재 완료(사전조건 7) → 아래는 **재정제**용. 즉시 실행 불필요.
-- ⚠️ 구조 소유주는 dbt 가 아님: SILVER=08_SILVER_테이블DDL, GOLD=03_top-down_gold/06_DDL.
--    전 모델 full_refresh:false + pre-hook TRUNCATE(fact/silver) / merge(dim) → DDL·FK·주석 보존.
--    따라서 `--full-refresh` 플래그는 **사용 금지**(무시되지만 혼동 유발).

-- 전체 재정제:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- 부분: GA4 샤드 입고 시(하류 XREF 포함) / CRM 도메인만:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.ga4+';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';

-- GOLD만(SILVER 테스트 게이트 우회):
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select path:models/gold';

-- WIDE 소비뷰만 재생성(tag 기반, 물리저장 0):
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select tag:gold_wide';

-- 이후 워크스페이스 코드 수정 시 새 버전 고정(거버넌스·재현성):
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
--   ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
--   COMMENT = '<변경 요약>';

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 스케줄 자동화 (TASK) : 준비되면 주석 해제
-- ─────────────────────────────────────────────────────────────────────────────
-- 주의:
--   1. WAREHOUSE 필수 — serverless task 는 EXECUTE DBT PROJECT 미지원.
--   2. TASK 는 dbt project 와 동일 스키마(GN_DW.OPS)에 생성.
--   3. 생성 직후 SUSPENDED 상태 → RESUME 해야 스케줄 동작.
--   4. R2 규칙 유지: run 금지·build 사용(run+test 게이트).
--   5. CRON 타임존은 KST 기준(Asia/Seoul). UTC 필요 시 UTC 로 교체.
--   6. TASK 생성 권한: GN_DW_ADMIN 에 EXECUTE TASK(account-level) 필요 시 ACCOUNTADMIN 선부여.
--      GRANT EXECUTE TASK ON ACCOUNT TO ROLE GN_DW_ADMIN;

-- (a) 전체 재정제 — 매일 오전 6시 KST:
-- CREATE OR ALTER TASK GN_DW.OPS.RUN_DW_PIPELINE_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   SCHEDULE = 'USING CRON 0 6 * * * Asia/Seoul'
--   COMMENT = 'DW_PIPELINE 일일 build(run+test) 자동 실행'
-- AS
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- (b) 활성화 (생성 후 SUSPENDED → RESUME):
-- ALTER TASK IF EXISTS GN_DW.OPS.RUN_DW_PIPELINE_DAILY RESUME;

-- (c) 상태 확인:
-- SHOW TASKS LIKE 'RUN_DW_PIPELINE_DAILY' IN SCHEMA GN_DW.OPS;

-- (d) 중지(일시 정지):
-- ALTER TASK IF EXISTS GN_DW.OPS.RUN_DW_PIPELINE_DAILY SUSPEND;

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 5 — SERVING 계층 (본 파일 범위 밖, 순서 참고용)
-- ─────────────────────────────────────────────────────────────────────────────
-- dbt 는 SILVER/GOLD 까지만 소유. SV/Agent 를 쓰려면 아래를 **이 순서대로** 별도 실행:
--   1. 05_SV-Agent_ai/02_SERVING_setup.sql
--        또는 02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql §E(grant) + §G(helper 뷰)
--        → DIM_MONTH · DIM_MEMBER_CURRENT 생성  ★ SV DDL 보다 반드시 먼저
--   2. 05_SV-Agent_ai/13_SV_AD_배포_추가작업.sql  → FACT_AD_COMBINED pre-join 뷰
--   3. 05_SV-Agent_ai/05_SV_DDL.sql               → CREATE SEMANTIC VIEW
-- 미실행 시 증상: "Table 'GN_DW.SERVING.DIM_MONTH' does not exist or not authorized"
