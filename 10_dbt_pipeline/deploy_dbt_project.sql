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
-- Step 1 — CREATE (최초 배포) : VERSION$1 자동 default
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
  COMMENT = 'dbt project 등 운영/툴링 객체 전용 (데이터 레이어 아님)';

-- CREATE DBT PROJECT 권한 (신 계정 실측: GN_DW_ADMIN 에 미부여 → ACCOUNTADMIN 이 선부여)
GRANT CREATE DBT PROJECT ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ADMIN;

-- 워크스페이스 경로 수정 필요함
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 4 — 스케줄 자동화 (TASK) : 준비되면 주석 해제
-- ─────────────────────────────────────────────────────────────────────────────
-- 주의:
--   1. WAREHOUSE 필수 — serverless task 는 EXECUTE DBT PROJECT 미지원.
--   2. TASK 는 dbt project 와 동일 스키마(GN_DW.OPS)에 생성.
--   3. 생성 직후 SUSPENDED 상태 → RESUME 해야 스케줄 동작.
--   4. R2 규칙 유지: run 금지·build 사용(run+test 게이트).
--   5. CRON 타임존은 KST 기준(Asia/Seoul). UTC 필요 시 UTC 로 교체.

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
