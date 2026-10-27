-- =============================================================================
-- Target     : TASK GN_DW.OPS."daily"
-- Purpose    : dbt 일일 실행용 Task ("daily") 생성 및 관리 정본 SQL
-- Owner      : GN_DW_ADMIN — 🔴 GN_DW_DBT 로 만들지 않는다. 운영계 dbt 모델 테이블 소유 = GN_DW_ADMIN · GN_DW_DBT 의 SILVER 권한 0건(R93 Q01·Q02 · 2026-10-27) ⇒ GN_DW_DBT 소유 Task 는 42501 로 실패한다
-- Schedule   : 매일 06:01 KST (USING CRON 1 6 * * * Asia/Seoul)
-- Warehouse  : GN_DW_ETL_WH
-- Definition : EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build'
-- =============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;
USE DATABASE GN_DW;
USE SCHEMA OPS;

-- 1. 일일 dbt build 실행 태스크 생성
CREATE OR ALTER TASK GN_DW.OPS."daily"
  WAREHOUSE = GN_DW_ETL_WH
  SCHEDULE = 'USING CRON 1 6 * * * Asia/Seoul'
  COMMENT = 'dbt 일일 build(run+test) 자동 실행 (06:01 KST)'
AS
  EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';

-- 2. 태스크 활성화 (생성 직후 SUSPENDED 상태이므로 RESUME 필요)
ALTER TASK GN_DW.OPS."daily" RESUME;

-- 3. 태스크 상태 및 실행 설정 확인
SHOW TASKS LIKE 'daily' IN SCHEMA GN_DW.OPS;

-- 실패 알림 = GN_DW.OPS.ALERT_DAILY_TASK_FAILED (85_실제 인수인계 문서/30_현업요청대응/_근거쿼리/R94_daily실패알림_배포.sql)

-- 4. 필요 시 일시 중지
-- ALTER TASK GN_DW.OPS."daily" SUSPEND;
