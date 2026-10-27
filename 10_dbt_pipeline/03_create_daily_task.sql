-- =============================================================================
-- Target     : TASK GN_DW.OPS."daily"
-- Purpose    : dbt 일일 실행용 Task ("daily") 생성 및 관리 정본 SQL
-- Owner      : GN_DW_DBT (또는 GN_DW_ADMIN)
-- Schedule   : 매일 06:01 KST (USING CRON 1 6 * * * Asia/Seoul)
-- Warehouse  : GN_DW_ETL_WH
-- Definition : EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build'
-- =============================================================================

USE ROLE GN_DW_DBT;
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

-- 4. 필요 시 일시 중지
-- ALTER TASK GN_DW.OPS."daily" SUSPEND;
