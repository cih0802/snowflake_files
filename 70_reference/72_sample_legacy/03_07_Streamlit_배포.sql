------------------------------------------------------
-- 3.9 Streamlit 대시보드 배포
-- PoC Streamlit 6종 중 운영 대상 5종을 GN_DW.GOLD로 마이그레이션
-- (테스트 앱은 이관 대상에서 제외)
-- 모든 앱은 GOLD View만 참조, query_warehouse = GN_DW_ANALYTICS_WH
------------------------------------------------------
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.GOLD;

------------------------------------------------------
-- 앱 소스 파일용 내부 스테이지
--   배포 절차: 각 앱 폴더에 streamlit_app.py(+environment.yml)를 PUT 후 CREATE STREAMLIT 실행
--   예) PUT file://./apps/campaign_ltv_cac/streamlit_app.py @ST_APPS_STAGE/campaign_ltv_cac AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
------------------------------------------------------
CREATE STAGE IF NOT EXISTS GN_DW.GOLD.ST_APPS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Streamlit 대시보드 소스 파일 스테이지';

------------------------------------------------------
-- 1) 캠페인별 LTV/CAC 분석  (참조: V_CAMPAIGN_LTV, V_CAMPAIGN_ROI)
------------------------------------------------------
CREATE OR REPLACE STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_LTV_CAC
    FROM '@GN_DW.GOLD.ST_APPS_STAGE/campaign_ltv_cac'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = GN_DW_ANALYTICS_WH
    TITLE = '캠페인별 LTV/CAC 분석'
    COMMENT = 'V_CAMPAIGN_LTV, V_CAMPAIGN_ROI 기반 캠페인 수익성 분석';

------------------------------------------------------
-- 2) 주요캠페인별 미납현황  (참조: V_PAYMENT_ANALYSIS)
------------------------------------------------------
CREATE OR REPLACE STREAMLIT GN_DW.GOLD.ST_UNPAID_STATUS
    FROM '@GN_DW.GOLD.ST_APPS_STAGE/unpaid_status'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = GN_DW_ANALYTICS_WH
    TITLE = '주요캠페인별 미납현황'
    COMMENT = 'V_PAYMENT_ANALYSIS 기반 캠페인별 미납 현황';

------------------------------------------------------
-- 3) 개발회원 후원여정 현황  (참조: V_MEMBER_JOURNEY, V_MEMBER_DEV_DETAIL)
------------------------------------------------------
CREATE OR REPLACE STREAMLIT GN_DW.GOLD.ST_MEMBER_JOURNEY
    FROM '@GN_DW.GOLD.ST_APPS_STAGE/member_journey'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = GN_DW_ANALYTICS_WH
    TITLE = '개발회원 후원여정 현황'
    COMMENT = 'V_MEMBER_JOURNEY, V_MEMBER_DEV_DETAIL 기반 회원 여정 분석';

------------------------------------------------------
-- 4) 주간중단회원 보고  (참조: V_DISCONTINUED_DETAIL)
------------------------------------------------------
CREATE OR REPLACE STREAMLIT GN_DW.GOLD.ST_WEEKLY_DISCONTINUED
    FROM '@GN_DW.GOLD.ST_APPS_STAGE/weekly_discontinued'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = GN_DW_ANALYTICS_WH
    TITLE = '주간중단회원 보고'
    COMMENT = 'V_DISCONTINUED_DETAIL 기반 주간 중단회원 리포트';

------------------------------------------------------
-- 5) 주요캠페인별 중단현황  (참조: V_DISCONTINUATION_REPORT, V_DISCONTINUED_DETAIL)
------------------------------------------------------
CREATE OR REPLACE STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_DISCONTINUED
    FROM '@GN_DW.GOLD.ST_APPS_STAGE/campaign_discontinued'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = GN_DW_ANALYTICS_WH
    TITLE = '주요캠페인별 중단현황'
    COMMENT = 'V_DISCONTINUATION_REPORT, V_DISCONTINUED_DETAIL 기반 캠페인별 중단 현황';

-- (참고) PoC '테스트' 앱은 운영 이관 대상에서 제외

------------------------------------------------------
-- 앱 사용 권한 부여 (분석/뷰어/서비스 Role)
------------------------------------------------------
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_LTV_CAC      TO ROLE GN_DW_ANALYST;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_LTV_CAC      TO ROLE GN_DW_VIEWER;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_LTV_CAC      TO ROLE GN_DW_SERVICE;

GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_UNPAID_STATUS         TO ROLE GN_DW_ANALYST;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_UNPAID_STATUS         TO ROLE GN_DW_VIEWER;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_UNPAID_STATUS         TO ROLE GN_DW_SERVICE;

GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_MEMBER_JOURNEY        TO ROLE GN_DW_ANALYST;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_MEMBER_JOURNEY        TO ROLE GN_DW_VIEWER;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_MEMBER_JOURNEY        TO ROLE GN_DW_SERVICE;

GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_WEEKLY_DISCONTINUED   TO ROLE GN_DW_ANALYST;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_WEEKLY_DISCONTINUED   TO ROLE GN_DW_VIEWER;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_WEEKLY_DISCONTINUED   TO ROLE GN_DW_SERVICE;

GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_DISCONTINUED TO ROLE GN_DW_ANALYST;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_DISCONTINUED TO ROLE GN_DW_VIEWER;
GRANT USAGE ON STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_DISCONTINUED TO ROLE GN_DW_SERVICE;

------------------------------------------------------
-- [배포 메모]
--   1. 각 앱 소스(streamlit_app.py)는 GOLD View만 조회하도록 작성
--   2. PUT으로 스테이지 폴더에 업로드 후 CREATE STREAMLIT 실행
--   3. 생성 후 라이브 버전 등록 필요:
--      ALTER STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_LTV_CAC      ADD LIVE VERSION FROM LAST;
--      ALTER STREAMLIT GN_DW.GOLD.ST_UNPAID_STATUS         ADD LIVE VERSION FROM LAST;
--      ALTER STREAMLIT GN_DW.GOLD.ST_MEMBER_JOURNEY        ADD LIVE VERSION FROM LAST;
--      ALTER STREAMLIT GN_DW.GOLD.ST_WEEKLY_DISCONTINUED   ADD LIVE VERSION FROM LAST;
--      ALTER STREAMLIT GN_DW.GOLD.ST_CAMPAIGN_DISCONTINUED ADD LIVE VERSION FROM LAST;
------------------------------------------------------
