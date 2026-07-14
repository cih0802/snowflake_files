------------------------------------------------------
-- 3.1 Database 생성
------------------------------------------------------
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS GN_DW
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = '굿네이버스 데이터 웨어하우스';

GRANT OWNERSHIP ON SCHEMA GN_DW.PUBLIC TO ROLE GN_DW_ADMIN REVOKE CURRENT GRANTS;
GRANT OWNERSHIP ON DATABASE GN_DW TO ROLE GN_DW_ADMIN REVOKE CURRENT GRANTS;

------------------------------------------------------
-- 3.2 Schema 생성
------------------------------------------------------
USE ROLE GN_DW_ADMIN;

CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_CRM
    WITH MANAGED ACCESS
    COMMENT = '원천 데이터 적재 - CRM (회원/납입/캠페인)';

CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_GA4
    WITH MANAGED ACCESS
    COMMENT = '원천 데이터 적재 - GA4 (웹/앱 방문, Google 광고)';

CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_AGENCY
    WITH MANAGED ACCESS
    COMMENT = '원천 데이터 적재 - 대행사 (디지털/DRTV/재송출 광고)';

CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_ERP
    WITH MANAGED ACCESS
    COMMENT = '원천 데이터 적재 - ERP (SMS/알림톡/마케팅 발송)';

CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
    WITH MANAGED ACCESS
    COMMENT = '정제/변환 레이어';

CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD
    WITH MANAGED ACCESS
    COMMENT = '분석 View + Semantic View + Agent + 예측 테이블 + Streamlit';

CREATE SCHEMA IF NOT EXISTS GN_DW.SECURITY
    WITH MANAGED ACCESS
    COMMENT = '보안 정책 객체 전용 (Network Rule, Masking Policy, Auth Policy)';

CREATE SCHEMA IF NOT EXISTS GN_DW.OPS
    WITH MANAGED ACCESS
    COMMENT = 'ETL 운영 인프라 전용 (ETL_LOG, Task, Alert, 프로시저)';

