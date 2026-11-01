------------------------------------------------------
-- 1. 환경 세팅
------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- 1.1 Timezone 설정 (Account 레벨)
ALTER ACCOUNT SET TIMEZONE = 'Asia/Seoul';

-- 1.2 Warehouse 생성

-- ETL / 데이터 적재용
CREATE WAREHOUSE IF NOT EXISTS GN_DW_ETL_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'ETL 및 데이터 적재 전용 (프로시저/태스크)';

-- 분석가 쿼리용
CREATE WAREHOUSE IF NOT EXISTS GN_DW_ANALYTICS_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = '분석가 쿼리 전용';

-- 개발/테스트용
CREATE WAREHOUSE IF NOT EXISTS GN_DW_DEV_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = '개발 및 테스트 전용';
