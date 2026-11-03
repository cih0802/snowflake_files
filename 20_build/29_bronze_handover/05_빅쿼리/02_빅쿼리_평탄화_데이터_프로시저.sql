-- BigQuery 원천 데이터 평탄화 프로시저
-- 기준일자(YYYYMMDD)를 입력받아 BigQuery의 일자별 원천 이벤트 데이터를 조회·정제하고, 주요 이벤트·사용자·기기·지역·유입경로 등의 정보를 BIGQUERY_REFINED_DATA에 통합 적재한다.
-- 입력받은 기준일자의 형식 및 실제 날짜 여부를 검증하고, events_YYYYMMDD 원천 테이블의 존재 여부를 확인한다.
-- 기준일자의 기존 BIGQUERY_REFINED_DATA 데이터를 삭제 후 재적재하여 동일 일자 데이터의 중복 적재를 방지한다.
-- GA4 event_params와 user_properties의 배열형 데이터를 조회하여 캠페인, 후원, 세션, 페이지, 검색, 결제, 동영상, 회원정보 등 주요 이벤트 속성을 개별 컬럼으로 추출한다.
-- user_ltv, device, geo, collected_traffic_source, session_traffic_source_last_click, traffic_source, ecommerce 등의 중첩 데이터를 분해하여 사용자·기기·지역·유입경로·전자상거래 관련 정보를 정형화한다.
-- session_traffic_source_last_click의 교차채널 캠페인, Google Ads, 수동 캠페인 정보를 추출하여 세션 단위 유입경로 분석이 가능하도록 구성한다.
-- GA4 items 배열 데이터는 상품 카테고리, 상품ID, 상품명, 매출, 가격, 프로모션, 수량 등의 상품 정보로 변환하여 저장한다.
-- 회원 ID(UP_MEMBER_ID)가 숫자형 7자리 미만인 경우 앞에 0을 추가하여 7자리 형식으로 표준화한다.
-- 최종 데이터는 GN_DW.SILVER.BIGQUERY_REFINED_DATA에 적재하여 GA4 원천 이벤트 데이터를 분석에 활용할 수 있는 정제·통합 데이터로 제공한다


------------------------------------------------------------
-- 빅쿼리 데이터 평탄화 저장 테이블 생성
------------------------------------------------------------
create or replace TABLE GN_DW.SILVER.BIGQUERY_REFINED_DATA (
	BATCH_EVENT_INDEX NUMBER(38,0) COMMENT '배치 내 이벤트 순번',
	EVENT_DATE VARCHAR(16777216) COMMENT '이벤트 발생일',
	EVENT_TIMESTAMP NUMBER(38,0) COMMENT '이벤트 발생 시각',
	EVENT_NAME VARCHAR(16777216) COMMENT '이벤트명',
	EVENT_VALUE_IN_USD VARCHAR(16777216) COMMENT '이벤트 금액(USD)',
	EVENT_BUNDLE_SEQUENCE_ID NUMBER(38,0) COMMENT '이벤트 번들 순번',
	IS_ACTIVE_USER BOOLEAN COMMENT '활성 사용자 여부',
	USER_ID VARCHAR(16777216) COMMENT '사용자 ID',
	USER_PSEUDO_ID VARCHAR(16777216) COMMENT 'GA 익명 사용자 ID',
	USER_FIRST_TOUCH_TIMESTAMP NUMBER(38,0) COMMENT '사용자 최초 접속 시각',
	EP_CAMPAIGN VARCHAR(16777216) COMMENT '캠페인명',
	EP_CAMPAIGN_ID VARCHAR(16777216) COMMENT '캠페인 ID',
	EP_CHANGE_DONATION_UP VARCHAR(16777216) COMMENT '후원 증액 여부',
	EP_CHANGE_DONATION_UP_AMOUNT VARCHAR(16777216) COMMENT '후원 증액 금액',
	EP_CONTENT VARCHAR(16777216) COMMENT '콘텐츠',
	EP_CURRENCY VARCHAR(16777216) COMMENT '금액 통화',
	EP_DONATION_ONCE VARCHAR(16777216) COMMENT '일시후원 여부',
	EP_DONATION_ONCE_AMOUNT VARCHAR(16777216) COMMENT '일시후원 금액',
	EP_DONATION_REGULAR VARCHAR(16777216) COMMENT '정기후원 여부',
	EP_DONATION_REGULAR_AMOUNT VARCHAR(16777216) COMMENT '정기후원 금액',
	EP_ENGAGED_SESSION_EVENT VARCHAR(16777216) COMMENT '참여 세션 이벤트 여부',
	EP_ENGAGEMENT_TIME_MSEC VARCHAR(16777216) COMMENT '참여 시간(ms)',
	EP_ENTRANCES VARCHAR(16777216) COMMENT '세션 진입 여부',
	EP_EVENT_ACTION VARCHAR(16777216) COMMENT '이벤트 액션',
	EP_EVENT_CATEGORY VARCHAR(16777216) COMMENT '이벤트 카테고리',
	EP_EVENT_LABEL VARCHAR(16777216) COMMENT '이벤트 라벨',
	EP_GA_SESSION_ID VARCHAR(16777216) COMMENT 'GA 세션 ID',
	EP_GA_SESSION_NUMBER VARCHAR(16777216) COMMENT '사용자 세션 순번',
	EP_GAD_CAMPAIGNID VARCHAR(16777216) COMMENT '구글애즈 캠페인 ID',
	EP_GAD_SOURCE VARCHAR(16777216) COMMENT '구글애즈 유입 소스',
	EP_GCLID VARCHAR(16777216) COMMENT '구글 광고 클릭 ID',
	EP_LINK_CLASSES VARCHAR(16777216) COMMENT '클릭 링크 클래스',
	EP_LINK_DOMAIN VARCHAR(16777216) COMMENT '클릭 링크 도메인',
	EP_LINK_ID VARCHAR(16777216) COMMENT '클릭 링크 ID',
	EP_LINK_IMAGE VARCHAR(16777216) COMMENT '클릭 이미지',
	EP_LINK_TEXT VARCHAR(16777216) COMMENT '클릭 링크 문구',
	EP_LINK_TITLE VARCHAR(16777216) COMMENT '클릭 링크 제목',
	EP_LINK_URL VARCHAR(16777216) COMMENT '클릭 링크 URL',
	EP_MEDIUM VARCHAR(16777216) COMMENT '유입 매체',
	EP_OUTBOUND VARCHAR(16777216) COMMENT '외부 링크 여부',
	EP_PAGE_LOCATION VARCHAR(16777216) COMMENT '페이지 URL',
	EP_PAGE_REFERRER VARCHAR(16777216) COMMENT '이전 페이지 URL',
	EP_PAGE_TITLE VARCHAR(16777216) COMMENT '페이지 제목',
	EP_PAYMENT_TYPE VARCHAR(16777216) COMMENT '결제수단',
	EP_PERCENT_SCROLLED VARCHAR(16777216) COMMENT '페이지 스크롤 비율',
	EP_PROMOTION_ID VARCHAR(16777216) COMMENT '프로모션 ID',
	EP_PROMOTION_NAME VARCHAR(16777216) COMMENT '프로모션명',
	EP_SEARCH_TERM VARCHAR(16777216) COMMENT '검색어',
	EP_SESSION_ENGAGED VARCHAR(16777216) COMMENT '세션 참여 여부',
	EP_SOURCE VARCHAR(16777216) COMMENT '유입 소스',
	EP_TERM VARCHAR(16777216) COMMENT '검색어',
	EP_TRANSACTION_ID VARCHAR(16777216) COMMENT '거래 ID',
	EP_VALUE VARCHAR(16777216) COMMENT '값',
	EP_VIDEO_CURRENT_TIME VARCHAR(16777216) COMMENT '동영상 현재 재생 시간',
	EP_VIDEO_DURATION VARCHAR(16777216) COMMENT '동영상 전체 재생 시간',
	EP_VIDEO_PERCENT VARCHAR(16777216) COMMENT '동영상 비율',
	EP_VIDEO_PROVIDER VARCHAR(16777216) COMMENT '동영상 플랫폼',
	EP_VIDEO_TITLE VARCHAR(16777216) COMMENT '동영상 제목',
	EP_VIDEO_URL VARCHAR(16777216) COMMENT '동영상 URL',
	UP_BIZ_TYPE VARCHAR(16777216) COMMENT '후원 사업 유형',
	UP_DONATION_TYPE VARCHAR(16777216) COMMENT '후원 유형',
	UP_DONOR_TYPE VARCHAR(16777216) COMMENT '후원자 유형',
	UP_LOGIN_STATUS VARCHAR(16777216) COMMENT '로그인 상태',
	UP_MEMBER_ID VARCHAR(16777216) COMMENT '회원 ID',
	UP_MEMBER_TYPE VARCHAR(16777216) COMMENT '회원 유형',
	UP_USER_ID VARCHAR(16777216) COMMENT 'UP사용자 ID',
	USER_LTV_CURRENCY VARCHAR(16777216) COMMENT 'LTV 금액 통화',
	USER_LTV_REVENUE VARCHAR(16777216) COMMENT '사용자 LTV',
	DEVICE_CATEGORY VARCHAR(16777216) COMMENT '기기 유형',
	DEVICE_IS_LIMITED_AD_TRACKING VARCHAR(16777216) COMMENT '기기 광고 추적 제한 여부',
	DEVICE_LANGUAGE VARCHAR(16777216) COMMENT '기기 언어',
	DEVICE_MOBILE_BRAND_NAME VARCHAR(16777216) COMMENT '모바일 기기 브랜드명',
	DEVICE_MOBILE_MARKETING_NAME VARCHAR(16777216) COMMENT '모바일 기기 마케팅명',
	DEVICE_MOBILE_MODEL_NAME VARCHAR(16777216) COMMENT '모바일 기기 모델명',
	DEVICE_MOBILE_OS_HARDWARE_MODEL VARCHAR(16777216) COMMENT '모바일 OS/하드웨어 모델',
	DEVICE_OPERATING_SYSTEM VARCHAR(16777216) COMMENT '기기 운영체제',
	DEVICE_OPERATING_SYSTEM_VERSION VARCHAR(16777216) COMMENT '기기 운영체제 버전',
	DEVICE_WEB_INFO_BROWSER VARCHAR(16777216) COMMENT '웹 브라우저',
	DEVICE_WEB_INFO_BROWSER_VERSION VARCHAR(16777216) COMMENT '웹 브라우저 버전',
	DEVICE_WEB_INFO_HOSTNAME VARCHAR(16777216) COMMENT '웹 호스트명',
	GEO_CITY VARCHAR(16777216) COMMENT '도시',
	GEO_CONTINENT VARCHAR(16777216) COMMENT '대륙',
	GEO_COUNTRY VARCHAR(16777216) COMMENT '국가',
	GEO_METRO VARCHAR(16777216) COMMENT '광역권',
	GEO_REGION VARCHAR(16777216) COMMENT '지역',
	GEO_SUB_CONTINENT VARCHAR(16777216) COMMENT '하위 대륙',
	CTS_MANUAL_CAMPAIGN_ID VARCHAR(16777216) COMMENT '수동 캠페인 ID',
	CTS_MANUAL_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '수동 캠페인명',
	CTS_MANUAL_CONTENT VARCHAR(16777216) COMMENT '수동 광고 소재',
	CTS_MANUAL_MEDIUM VARCHAR(16777216) COMMENT '수동 유입 매체',
	CTS_MANUAL_SOURCE VARCHAR(16777216) COMMENT '수동 유입 소스',
	CTS_MANUAL_TERM VARCHAR(16777216) COMMENT '수동 검색어/키워드',
	STSLC_CRC_CAMPAIGN_ID VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 ID',
	STSLC_CRC_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인명',
	STSLC_CRC_DEFAULT_CHANNEL_GROUP VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 기본 채널',
	STSLC_CRC_MEDIUM VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 유입 매체',
	STSLC_CRC_PRIMARY_CHANNEL_GROUP VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 주요 채널',
	STSLC_CRC_SOURCE VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캄패인 유입 소스',
	STSLC_CRC_SOURCE_PLATFORM VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 소스 플랫폼',
	STSLC_GAC_AD_GROUP_ID VARCHAR(16777216) COMMENT '세션 최종 클릭 구글애즈 광고그룹 ID',
	STSLC_GAC_AD_GROUP_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 구글애즈 광고그룹명',
	STSLC_GAC_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 구글애즈 캠페인명',
	STSLC_MC_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 캠페인명',
	STSLC_MC_CONTENT VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 광고 소재',
	STSLC_MC_MEDIUM VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 유입 매체',
	STSLC_MC_SOURCE VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 유입 소스',
	STSLC_MC_SOURCE_PLATFORM VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 소스 플랫폼',
	STSLC_MC_TERM VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 검색어/키워드',
	TS_MEDIUM VARCHAR(16777216) COMMENT 'TS유입 매체',
	TS_NAME VARCHAR(16777216) COMMENT 'TS유입 객체명',
	TS_SOURCE VARCHAR(16777216) COMMENT 'TS유입 소스',
	STREAM_ID VARCHAR(16777216) COMMENT '스트림 ID',
	PLATFORM VARCHAR(16777216) COMMENT '플랫폼',
	ECOMMERCE_PURCHASE_REVENUE VARCHAR(16777216) COMMENT '이커머스 후원 금액',
	ECOMMERCE_TOTAL_ITEM_QUANTITY VARCHAR(16777216) COMMENT '이커머스 전체 상품 수량',
	ECOMMERCE_TRANSACTION_ID VARCHAR(16777216) COMMENT '이커머스 거래 ID',
	ECOMMERCE_UNIQUE_ITEMS VARCHAR(16777216) COMMENT '이커머스 고유 상품',
	ITEMS ARRAY COMMENT '후원 항목 정보'
)COMMENT='빅쿼리 평탄화 데이터'
;




------------------------------------------------------------
-- 7-2. [프로시저 본체] Snowflake BRONZE_BIGQUERY -> 평단화하여 GN_DW.SILVER.BIGQUERY_REFINED_DATA에 인입
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.BRONZE_BIGQUERY.SP_LOAD_BIGQUERY_REFINED_DATA(P_YYYYMMDD VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_table_name VARCHAR;
    v_table_exists NUMBER;
BEGIN
    -- YYYYMMDD 형식 및 유효한 날짜 검증
    IF (
           P_YYYYMMDD IS NULL
           OR NOT REGEXP_LIKE(P_YYYYMMDD, '^[0-9]{8}$')
           OR TRY_TO_DATE(P_YYYYMMDD, 'YYYYMMDD') IS NULL
       )
    THEN
        RETURN 'ERROR: P_YYYYMMDD는 유효한 YYYYMMDD 형식이어야 합니다. 입력값=' || COALESCE(P_YYYYMMDD, 'NULL');
    END IF;

    -- 대상 테이블명 생성
    v_table_name := 'GN_DW.BRONZE_BIGQUERY."events_' || P_YYYYMMDD || '"';
    
    -- 원천 테이블 존재 여부 확인
    SELECT COUNT(*)
      INTO :v_table_exists
      FROM GN_DW.INFORMATION_SCHEMA.TABLES
     WHERE TABLE_SCHEMA = 'BRONZE_BIGQUERY'
       AND TABLE_NAME = 'events_' || :P_YYYYMMDD;


    -- 원천 테이블이 없는 경우
    IF (v_table_exists = 0)
    THEN
        RETURN 'ERROR: 원천 테이블이 존재하지 않습니다. 테이블명='
               || v_table_name;
    END IF;
    
    -- 기존 데이터 삭제
    DELETE FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
    WHERE EVENT_DATE = :P_YYYYMMDD;

    INSERT INTO GN_DW.SILVER.BIGQUERY_REFINED_DATA
    SELECT 
        t."batch_event_index",
        t."event_date",
        t."event_timestamp",
        t."event_name",
        t."event_value_in_usd",
        t."event_bundle_sequence_id",
        t."is_active_user",
        t."user_id",
        t."user_pseudo_id",
        t."user_first_touch_timestamp",
        COALESCE(FILTER(t."event_params", x -> x:key = 'campaign')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'campaign')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'campaign')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'campaign')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'campaign_id')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'campaign_id')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'campaign_id')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'campaign_id')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'change_donation_up')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'change_donation_up')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'change_donation_up')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'change_donation_up')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'change_donation_up_amount')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'change_donation_up_amount')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'change_donation_up_amount')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'change_donation_up_amount')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'content')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'content')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'content')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'content')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'currency')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'currency')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'currency')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'currency')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'donation_once')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_once')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_once')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_once')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'donation_once_amount')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_once_amount')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_once_amount')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_once_amount')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'donation_regular')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_regular')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_regular')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_regular')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'donation_regular_amount')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_regular_amount')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_regular_amount')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'donation_regular_amount')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'engaged_session_event')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'engaged_session_event')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'engaged_session_event')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'engaged_session_event')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'engagement_time_msec')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'engagement_time_msec')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'engagement_time_msec')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'engagement_time_msec')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'entrances')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'entrances')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'entrances')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'entrances')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'event_action')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'event_action')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'event_action')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'event_action')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'event_category')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'event_category')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'event_category')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'event_category')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'event_label')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'event_label')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'event_label')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'event_label')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'ga_session_id')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'ga_session_id')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'ga_session_id')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'ga_session_id')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'ga_session_number')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'ga_session_number')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'ga_session_number')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'ga_session_number')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'gad_campaignid')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'gad_campaignid')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'gad_campaignid')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'gad_campaignid')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'gad_source')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'gad_source')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'gad_source')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'gad_source')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'gclid')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'gclid')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'gclid')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'gclid')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_classes')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_classes')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_classes')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_classes')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_domain')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_domain')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_domain')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_domain')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_id')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_id')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_id')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_id')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_image')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_image')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_image')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_image')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_text')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_text')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_text')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_text')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_title')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_title')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_title')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_title')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'link_url')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'link_url')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'link_url')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'link_url')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'medium')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'medium')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'medium')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'medium')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'outbound')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'outbound')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'outbound')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'outbound')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'page_location')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'page_location')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'page_location')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'page_location')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'page_referrer')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'page_referrer')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'page_referrer')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'page_referrer')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'page_title')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'page_title')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'page_title')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'page_title')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'payment_type')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'payment_type')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'payment_type')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'payment_type')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'percent_scrolled')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'percent_scrolled')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'percent_scrolled')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'percent_scrolled')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'promotion_id')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'promotion_id')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'promotion_id')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'promotion_id')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'promotion_name')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'promotion_name')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'promotion_name')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'promotion_name')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'search_term')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'search_term')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'search_term')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'search_term')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'session_engaged')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'session_engaged')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'session_engaged')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'session_engaged')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'source')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'source')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'source')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'source')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'term')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'term')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'term')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'term')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'transaction_id')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'transaction_id')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'transaction_id')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'transaction_id')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'value')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'value')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'value')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'value')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'video_current_time')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'video_current_time')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'video_current_time')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'video_current_time')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'video_duration')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'video_duration')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'video_duration')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'video_duration')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'video_percent')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'video_percent')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'video_percent')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'video_percent')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'video_provider')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'video_provider')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'video_provider')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'video_provider')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'video_title')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'video_title')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'video_title')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'video_title')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."event_params", x -> x:key = 'video_url')[0]:value:string_value::STRING, FILTER(t."event_params", x -> x:key = 'video_url')[0]:value:int_value::STRING, FILTER(t."event_params", x -> x:key = 'video_url')[0]:value:float_value::STRING, FILTER(t."event_params", x -> x:key = 'video_url')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'biz_type')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'biz_type')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'biz_type')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'biz_type')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'donation_type')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'donation_type')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'donation_type')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'donation_type')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'donor_type')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'donor_type')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'donor_type')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'donor_type')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'login_status')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'login_status')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'login_status')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'login_status')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'member_id')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'member_id')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'member_id')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'member_id')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'member_type')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'member_type')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'member_type')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'member_type')[0]:value:double_value::STRING),
        COALESCE(FILTER(t."user_properties", x -> x:key = 'user_id')[0]:value:string_value::STRING, FILTER(t."user_properties", x -> x:key = 'user_id')[0]:value:int_value::STRING, FILTER(t."user_properties", x -> x:key = 'user_id')[0]:value:float_value::STRING, FILTER(t."user_properties", x -> x:key = 'user_id')[0]:value:double_value::STRING),
        t."user_ltv":currency::STRING,
        t."user_ltv":revenue::STRING,
        t."device":category::STRING,
        t."device":is_limited_ad_tracking::STRING,
        t."device":language::STRING,
        t."device":mobile_brand_name::STRING,
        t."device":mobile_marketing_name::STRING,
        t."device":mobile_model_name::STRING,
        t."device":mobile_os_hardware_model::STRING,
        t."device":operating_system::STRING,
        t."device":operating_system_version::STRING,
        t."device":web_info:browser::STRING,
        t."device":web_info:browser_version::STRING,
        t."device":web_info:hostname::STRING,
        t."geo":city::STRING,
        t."geo":continent::STRING,
        t."geo":country::STRING,
        t."geo":metro::STRING,
        t."geo":region::STRING,
        t."geo":sub_continent::STRING,
        t."collected_traffic_source":manual_campaign_id::STRING,
        t."collected_traffic_source":manual_campaign_name::STRING,
        t."collected_traffic_source":manual_content::STRING,
        t."collected_traffic_source":manual_medium::STRING,
        t."collected_traffic_source":manual_source::STRING,
        t."collected_traffic_source":manual_term::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:campaign_id::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:campaign_name::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:default_channel_group::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:medium::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:primary_channel_group::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:source::STRING,
        t."session_traffic_source_last_click":cross_channel_campaign:source_platform::STRING,
        t."session_traffic_source_last_click":google_ads_campaign:ad_group_id::STRING,
        t."session_traffic_source_last_click":google_ads_campaign:ad_group_name::STRING,
        t."session_traffic_source_last_click":google_ads_campaign:campaign_name::STRING,
        t."session_traffic_source_last_click":manual_campaign:campaign_name::STRING,
        t."session_traffic_source_last_click":manual_campaign:content::STRING,
        t."session_traffic_source_last_click":manual_campaign:medium::STRING,
        t."session_traffic_source_last_click":manual_campaign:source::STRING,
        t."session_traffic_source_last_click":manual_campaign:source_platform::STRING,
        t."session_traffic_source_last_click":manual_campaign:term::STRING,
        t."traffic_source":medium::STRING,
        t."traffic_source":name::STRING,
        t."traffic_source":source::STRING,
        t."stream_id",
        t."platform",
        t."ecommerce":purchase_revenue::STRING,
        t."ecommerce":total_item_quantity::STRING,
        t."ecommerce":transaction_id::STRING,
        t."ecommerce":unique_items::STRING,
        CASE
            WHEN ARRAY_SIZE(t."items") > 0 
                THEN TRANSFORM(t."items", x -> OBJECT_CONSTRUCT_KEEP_NULL(
                    'item_category', x:item_category::STRING,
                    'item_id', x:item_id::STRING,
                    'item_name', x:item_name::STRING,
                    'item_revenue', x:item_revenue::NUMBER,
                    'price', x:price::NUMBER,
                    'promotion_id', x:promotion_id::STRING,
                    'promotion_name', x:promotion_name::STRING,
                    'quantity', x:quantity::NUMBER
                ))
            ELSE NULL
        END
    FROM IDENTIFIER(:v_table_name) t;

    -- UP_MEMBER_ID 7자리 업데이트
    UPDATE GN_DW.SILVER.BIGQUERY_REFINED_DATA
    SET UP_MEMBER_ID = LPAD(UP_MEMBER_ID, 7, '0')
    WHERE 
        EVENT_DATE = :P_YYYYMMDD
        AND UP_MEMBER_ID IS NOT NULL
        AND TRY_TO_NUMBER(UP_MEMBER_ID) IS not NULL
        AND LENGTH(UP_MEMBER_ID) < 7; 
    -- 동적 SQL 실행
    RETURN 'Done: ' || v_table_name;
END;
$$;


