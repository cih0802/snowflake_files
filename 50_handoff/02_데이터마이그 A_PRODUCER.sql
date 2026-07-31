-- A 계정 (Provider), ACCOUNTADMIN 역할
USE ROLE ACCOUNTADMIN;

CREATE SHARE mig_share COMMENT = 'A->B 데이터 마이그레이션 공유';

-- 공유할 DB/스키마/테이블에 대한 사용 권한 부여
GRANT USAGE   ON DATABASE  GN_DW            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_CRM            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_GA4            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_ERP            TO SHARE mig_share;
GRANT USAGE   ON SCHEMA  GN_DW.BRONZE_AGENCY            TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_CRM TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_GA4 TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_ERP TO SHARE mig_share;
GRANT SELECT  ON ALL TABLES IN SCHEMA GN_DW.BRONZE_AGENCY TO SHARE mig_share;
-- 특정 테이블만: GRANT SELECT ON TABLE src_db.src_schema.tbl TO SHARE mig_share;
-- 주의: ALL TABLES는 '현재 존재하는' 테이블만 대상. 이후 추가된 테이블은 재부여 필요.

-- B 계정을 공유 대상으로 추가 (B의 account locator 또는 org.account 사용)
-- ALTER SHARE mig_share ADD ACCOUNTS = <account locator>;
ALTER SHARE mig_share ADD ACCOUNTS = GB72026;

-- 확인
SHOW GRANTS TO SHARE mig_share;
SHOW SHARES LIKE 'MIG_SHARE';

-- C 계정 공유용 DDL 저장 ========================
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_CRM', TRUE);
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_GA4', TRUE);
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_ERP', TRUE);
-- SELECT GET_DDL('SCHEMA', 'GN_DW.BRONZE_AGENCY', TRUE);