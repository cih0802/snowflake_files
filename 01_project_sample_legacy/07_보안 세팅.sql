------------------------------------------------------
-- 7. 보안 세팅
------------------------------------------------------

------------------------------------------------------
-- 7.1 네트워크 룰 생성 (ACCOUNTADMIN 필요: DB 스키마 내 오브젝트 생성)
------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- 사무실 IP (실제 IP로 교체 필요)
CREATE OR REPLACE NETWORK RULE GN_DW.GOLD.NR_OFFICE_IP
    TYPE = IPV4
    MODE = INGRESS
    VALUE_LIST = ('123.214.185.241')
    COMMENT = '사무실 IP 대역';

-- VPN IP (실제 IP로 교체 필요)
CREATE OR REPLACE NETWORK RULE GN_DW.GOLD.NR_VPN_IP
    TYPE = IPV4
    MODE = INGRESS
    VALUE_LIST = ('198.51.100.0/24')
    COMMENT = 'VPN 접속 IP 대역';

-- 서비스/ETL 서버 IP (실제 IP로 교체 필요)
CREATE OR REPLACE NETWORK RULE GN_DW.GOLD.NR_SERVICE_IP
    TYPE = IPV4
    MODE = INGRESS
    VALUE_LIST = ('192.0.2.10', '192.0.2.11')
    COMMENT = '서비스/ETL 서버 IP';

------------------------------------------------------
-- 7.1 네트워크 정책 생성
------------------------------------------------------

-- Account 레벨 정책: 사무실 + VPN + 서비스
CREATE OR REPLACE NETWORK POLICY NP_GN_DW_ACCOUNT
    ALLOWED_NETWORK_RULE_LIST = (
        'GN_DW.GOLD.NR_OFFICE_IP',
        'GN_DW.GOLD.NR_VPN_IP',
        'GN_DW.GOLD.NR_SERVICE_IP'
    )
    COMMENT = 'GN_DW 계정 네트워크 정책 - 사무실/VPN/서비스만 허용';

-- 서비스 계정용 정책: 서비스 IP만
CREATE OR REPLACE NETWORK POLICY NP_GN_DW_SERVICE
    ALLOWED_NETWORK_RULE_LIST = (
        'GN_DW.GOLD.NR_SERVICE_IP'
    )
    COMMENT = '서비스 계정 전용 - 서비스 IP만 허용';

-- [주의] 활성화 전 본인 IP가 포함되어 있는지 반드시 확인
-- SELECT CURRENT_IP_ADDRESS();

-- Account 레벨 활성화 (테스트 후 주석 해제)
-- ALTER ACCOUNT SET NETWORK_POLICY = NP_GN_DW_ACCOUNT;

-- 서비스 유저에 개별 정책 적용 (유저 생성 후)
-- ALTER USER GN_SERVICE_01 SET NETWORK_POLICY = NP_GN_DW_SERVICE;

------------------------------------------------------
-- 7.2 마스킹 정책
------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- 마스킹 관리 Role 생성
CREATE ROLE IF NOT EXISTS GN_DW_MASKING_ADMIN
    COMMENT = '마스킹 정책 관리 전용';
GRANT CREATE MASKING POLICY ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_MASKING_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE GN_DW_MASKING_ADMIN;
GRANT ROLE GN_DW_MASKING_ADMIN TO ROLE GN_DW_ADMIN;

-- 회원번호 마스킹: ENGINEER/ADMIN은 원본, 나머지는 부분 마스킹
USE ROLE GN_DW_MASKING_ADMIN;

CREATE OR REPLACE MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID
    AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('GN_DW_ADMIN', 'GN_DW_ENGINEER') THEN val
        WHEN val IS NULL THEN NULL
        ELSE LEFT(val, 4) || '****'
    END
    COMMENT = '회원번호 마스킹: 앞4자리만 노출';

-- 마스킹 적용: SILVER 물리 테이블의 회원번호 컬럼에 직접 적용
--   (CREATE OR REPLACE VIEW 시 정책 매핑 단절 방지 / GOLD View까지 자동 상속됨)
-- ALTER TABLE GN_DW.SILVER.DIM_MEMBER_ATTRIBUTE
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_PAYMENT_HISTORY
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_MEMBER_DEV_ALL
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_DISCONTINUED_MEMBER
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_SMS_ALIMTALK_SEND
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_MARKETING_SEND_NEW
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_AD_GA_AUDIENCE
--     MODIFY COLUMN "회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;

-- [참고] 일시/정기 회원 식별자 컬럼(컬럼명이 "회원번호"가 아님)도 필요 시 동일 정책 적용:
-- ALTER TABLE GN_DW.SILVER.DIM_TEMP_TO_REGULAR_MATCH
--     MODIFY COLUMN "회원번호(정기)" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.DIM_TEMP_TO_REGULAR_MATCH
--     MODIFY COLUMN "회원번호(일시)" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;
-- ALTER TABLE GN_DW.SILVER.FACT_TEMP_MEMBER_DONATION
--     MODIFY COLUMN "일시회원번호" SET MASKING POLICY GN_DW.GOLD.MASK_MEMBER_ID;

------------------------------------------------------
-- 7.3 MFA / 인증 정책
------------------------------------------------------
USE ROLE SECURITYADMIN;

-- MFA 강제 인증 정책 (ADMIN급 유저 대상)
CREATE OR REPLACE AUTHENTICATION POLICY GN_DW.GOLD.AUTH_MFA_REQUIRED
    CLIENT_TYPES = ('SNOWFLAKE_UI', 'DRIVERS')
    MFA_ENROLLMENT = 'REQUIRED'
    MFA_POLICY = ( ALLOWED_METHODS = ('TOTP') )
    COMMENT = 'MFA 필수 인증 정책 (MFA 등록 강제, 인증앱 TOTP)';

-- ADMIN 유저에 적용 (유저 생성 후 주석 해제)
-- ALTER USER TRIALADMIN SET AUTHENTICATION POLICY = GN_DW.GOLD.AUTH_MFA_REQUIRED;
