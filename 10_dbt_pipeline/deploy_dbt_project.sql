-- GN_DW dbt PROJECT 최초 생성 (계정 이전 cs94293 후 재배포) — 정본 위치 GN_DW.OPS.DW_PIPELINE
-- Co-authored with CoCo

-- ============================================================================
-- 근거: 10_dbt_pipeline/00_배포운영_통합_20260715.md §1 (정본, 구 _archive/99 대체)
--   · 프로젝트 배치 = 운영/툴링 스키마 GN_DW.OPS (데이터레이어 SILVER/GOLD와 분리)
--   · 프로젝트명 = DW_PIPELINE (구 계정 동일: GN_DW.OPS.DW_PIPELINE, 구 default=VERSION$6)
-- 사전조건:
--   1. GN_DW.OPS 스키마 존재 (확인됨 — "ETL 운영 인프라 전용")
--   2. 워크스페이스 10_dbt_pipeline/ 에 dbt_project.yml + models(SILVER 32 + GOLD 33=65) 존재 (확인됨)
--   3. RBAC 역할 6종·SERVING·helper 뷰 생성 완료 (확인됨)
--   4. 워크스페이스 dbt build green 확인됨 (사용자 확인)
-- 주의: 신규 계정이므로 versions/live = 최신 워크스페이스 코드(07-16 WIDE 9/9·07-20 CRM_BIZ_TARGET
--       measure 정정 포함) → CREATE 시 VERSION$1 이 곧 최신. 구 계정의 VERSION 드리프트 이슈 무관.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1 — CREATE (최초 배포) : VERSION$1 자동 default
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 운영/툴링 객체 전용 (데이터 레이어 아님)';

-- CREATE DBT PROJECT 권한 (신 계정 실측: GN_DW_ADMIN 에 미부여 → ACCOUNTADMIN 이 선부여)
GRANT CREATE DBT PROJECT ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ADMIN;

CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = 'BRONZE→SILVER 32 + SILVER→GOLD 24(dim15+fact9)+WIDE 9. 정본 09_SILVER_적재쿼리_20260714.';

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
-- 전체 재정제:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- 부분: GA4 샤드 입고 시(하류 XREF 포함) / CRM 도메인만:
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.ga4+';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select silver.crm';

-- GOLD만(SILVER 테스트 게이트 우회):
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select path:models/gold';

-- 이후 워크스페이스 코드 수정 시 새 버전 고정(거버넌스·재현성):
-- ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
--   ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
--   COMMENT = '<변경 요약>';
