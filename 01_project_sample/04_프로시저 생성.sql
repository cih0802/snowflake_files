------------------------------------------------------
-- 4. 프로시저 생성
------------------------------------------------------
USE ROLE GN_DW_ENGINEER;
USE WAREHOUSE GN_DW_ETL_WH;

------------------------------------------------------
-- 4.3 유틸리티: ETL 로그 테이블
------------------------------------------------------
CREATE TABLE IF NOT EXISTS GN_DW.SILVER.ETL_LOG (
    LOG_ID NUMBER AUTOINCREMENT,
    PROC_NAME VARCHAR,
    STATUS VARCHAR,
    ROW_COUNT NUMBER,
    ERROR_MSG VARCHAR,
    STARTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ENDED_AT TIMESTAMP_NTZ
);

------------------------------------------------------
-- 4.3 SP_LOG_ETL_STATUS
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_LOG_ETL_STATUS(
    PROC_NAME VARCHAR,
    STATUS VARCHAR,
    ROW_COUNT NUMBER DEFAULT 0,
    ERROR_MSG VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO GN_DW.SILVER.ETL_LOG (PROC_NAME, STATUS, ROW_COUNT, ERROR_MSG, ENDED_AT)
    VALUES (:PROC_NAME, :STATUS, :ROW_COUNT, :ERROR_MSG, CURRENT_TIMESTAMP());
    RETURN 'OK';
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_DIM_CAMPAIGN
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_DIM_CAMPAIGN()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.DIM_CAMPAIGN_CODE AS
    SELECT
        TRIM("브랜드코드") AS "브랜드코드",
        TRIM("브랜드명") AS "브랜드명",
        "브랜드사용여부",
        "브랜드사용부서",
        "브랜드사용부서코드",
        TRIM("상위캠페인코드") AS "상위캠페인코드",
        TRIM("상위캠페인명") AS "상위캠페인명",
        "상위캠페인사용여부",
        TRIM("세부캠페인명") AS "세부캠페인명",
        TRIM("세부캠페인코드") AS "세부캠페인코드",
        "세부캠페인사용부서(실적부서)",
        "실적부서코드",
        "세부캠페인시작일",
        "공통브랜드명",
        "공통상위캠페인명",
        "국내해외구분"
    FROM GN_DW.BRONZE.DIM_CAMPAIGN_CODE
    WHERE "세부캠페인코드" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.DIM_CAMPAIGN_CODE;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_CAMPAIGN', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_CAMPAIGN', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_DIM_MEMBER
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_DIM_MEMBER()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.DIM_MEMBER_ATTRIBUTE AS
    SELECT
        "회원번호",
        COALESCE(NULLIF(TRIM("성별"), ''), '미상') AS "성별",
        COALESCE(NULLIF(TRIM("연령대"), ''), '미상') AS "연령대",
        COALESCE(NULLIF(TRIM("지역"), ''), '미상') AS "지역"
    FROM GN_DW.BRONZE.DIM_MEMBER_ATTRIBUTE
    WHERE "회원번호" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.DIM_MEMBER_ATTRIBUTE;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_MEMBER', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_MEMBER', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_PAYMENT
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_PAYMENT()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_PAYMENT_HISTORY AS
    SELECT
        "회원번호",
        SPNSR_NO,
        SPNSR_BSNS_NO,
        "회비청구월",
        LEFT(TO_VARCHAR("회비청구월"), 4) AS "청구연도",
        LEFT(TO_VARCHAR("회비청구월"), 6) AS "청구월",
        "청구금액",
        "납입금액",
        COALESCE("청구금액", 0) - COALESCE("납입금액", 0) AS "미납금액",
        "납입일",
        TRY_TO_DATE("납입일", 'YYYYMMDD') AS "납입일자",
        "납입구분",
        "비고"
    FROM GN_DW.BRONZE.FACT_PAYMENT_HISTORY
    WHERE "회원번호" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_PAYMENT_HISTORY;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_PAYMENT', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_PAYMENT', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_MEMBER_DEV
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_MEMBER_DEV()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_MEMBER_DEV_ALL AS
    SELECT
        "법인구분",
        "후원신청일",
        TRY_TO_DATE(TO_VARCHAR("후원신청일"), 'YYYYMMDD') AS "후원신청일자",
        LEFT(TO_VARCHAR("후원신청일"), 6) AS "신청월",
        LEFT(TO_VARCHAR("후원신청일"), 4) AS "신청연도",
        "실적부서코드",
        "실적부서",
        "브랜드ID",
        "브랜드",
        "홍보방법",
        "가입경로",
        "상위캠페인코드",
        "상위캠페인",
        "세부캠페인코드",
        "세부캠페인",
        "후원사업ID",
        "후원사업",
        "개발구분",
        "회원번호",
        "금액",
        SPNSR_NO,
        SPNSR_BSNS_NO,
        "금액" / 10000.0 AS "개발실적_건"
    FROM GN_DW.BRONZE.FACT_MEMBER_DEV_ALL
    WHERE "회원번호" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_MEMBER_DEV_ALL;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_MEMBER_DEV', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_MEMBER_DEV', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_DISCONTINUED
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_DISCONTINUED()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_DISCONTINUED_MEMBER AS
    SELECT
        "순번",
        "법인구분",
        "회원번호",
        "회원구분",
        "납입방식",
        "후원금액",
        "가입일",
        TRY_TO_DATE(TO_VARCHAR("가입일"), 'YYYYMMDD') AS "가입일자",
        "중단일",
        TRY_TO_DATE(TO_VARCHAR("중단일"), 'YYYYMMDD') AS "중단일자",
        LEFT(TO_VARCHAR("가입일"), 4) AS "가입연도",
        LEFT(TO_VARCHAR("중단일"), 4) AS "중단연도",
        LEFT(TO_VARCHAR("가입일"), 6) AS "가입월",
        LEFT(TO_VARCHAR("중단일"), 6) AS "중단월",
        DATEDIFF('day',
            TRY_TO_DATE(TO_VARCHAR("가입일"), 'YYYYMMDD'),
            TRY_TO_DATE(TO_VARCHAR("중단일"), 'YYYYMMDD')
        ) AS "유지일수",
        ROUND(DATEDIFF('day',
            TRY_TO_DATE(TO_VARCHAR("가입일"), 'YYYYMMDD'),
            TRY_TO_DATE(TO_VARCHAR("중단일"), 'YYYYMMDD')
        ) / 30.0, 1) AS "유지개월수",
        "중단사유",
        "가입캠페인(세부캠페인)",
        "브랜드",
        "상위캠페인",
        "가입부서(실적부서)"
    FROM GN_DW.BRONZE.FACT_DISCONTINUED_MEMBER
    WHERE "회원번호" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_DISCONTINUED_MEMBER;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DISCONTINUED', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DISCONTINUED', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_DIGITAL_AD
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_DIGITAL_AD()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_DIGITAL_AD_DETAIL AS
    SELECT
        "연도",
        "국내/해외",
        "사업/사례",
        "캠페인 유형",
        "광고유형",
        "월",
        "기기",
        "매체",
        "날짜",
        "주차",
        "일자",
        "요일",
        "캠페인명",
        "소재",
        COALESCE("노출수", 0) AS "노출수",
        COALESCE("클릭수", 0) AS "클릭수",
        COALESCE("GA 광고비", 0) AS "GA 광고비",
        COALESCE("GA 전환명수", 0) AS "GA 전환명수",
        COALESCE("GA 개발건수", 0) AS "GA 개발건수",
        "상위캠페인명",
        CASE WHEN "클릭수" > 0 THEN ROUND("GA 광고비" / "클릭수", 0) ELSE NULL END AS "CPC",
        CASE WHEN "노출수" > 0 THEN ROUND("클릭수" * 100.0 / "노출수", 2) ELSE NULL END AS "CTR"
    FROM GN_DW.BRONZE.FACT_DIGITAL_AD_DETAIL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_DIGITAL_AD_DETAIL;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DIGITAL_AD', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DIGITAL_AD', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_SMS
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_SMS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_SMS_ALIMTALK_SEND AS
    SELECT
        "순번",
        "발송구분(대)",
        "발송구분(중)",
        "발송구분(소)",
        "제목",
        TRY_TO_NUMBER("총건수") AS "총건수",
        TRY_TO_NUMBER("성공건수") AS "성공건수",
        "회원번호",
        TRY_TO_TIMESTAMP("발송일시") AS "발송일시",
        "발송상태",
        "대체발송",
        "등록일",
        TRY_TO_DOUBLE("성공률(%)") AS "성공률",
        COALESCE("일시후원여부", 'N') AS "일시후원여부"
    FROM GN_DW.BRONZE.FACT_SMS_ALIMTALK_SEND;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_SMS_ALIMTALK_SEND;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_SMS', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_SMS', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_AD_GA
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_AD_GA()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_AD_GA_AUDIENCE AS
    SELECT
        "날짜",
        TRY_TO_DATE(TO_VARCHAR("날짜"), 'YYYYMMDD') AS "날짜자",
        "잠재고객이름",
        "세션캠페인",
        "회원번호",
        COALESCE("세션수", 0) AS "세션수",
        COALESCE("활성사용자", 0) AS "활성사용자"
    FROM GN_DW.BRONZE.FACT_AD_GA_AUDIENCE;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_AD_GA_AUDIENCE;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_AD_GA', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_AD_GA', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_AD_META
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_AD_META()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_AD_META AS
    SELECT
        "일",
        TRY_TO_DATE("일") AS "일자",
        "캠페인이름",
        "광고세트이름",
        "광고이름",
        COALESCE("노출", 0) AS "노출",
        COALESCE("링크클릭", 0) AS "링크클릭",
        COALESCE("지출금액_KRW", 0) AS "지출금액_KRW",
        "캠페인예산",
        "캠페인예산유형",
        "광고세트예산",
        "광고세트예산유형",
        "구매",
        "구매당비용",
        TRY_TO_DATE("보고시작") AS "보고시작",
        TRY_TO_DATE("보고종료") AS "보고종료"
    FROM GN_DW.BRONZE.FACT_AD_META;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_AD_META;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_AD_META', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_AD_META', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_GA_VISITS (TOTAL/PC/MOBILE/APP)
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_GA_VISITS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_GA_VISITS_TOTAL AS
    SELECT
        "페이지경로", "이벤트이름", "세션캠페인", "회원ID",
        TRY_TO_NUMBER("세션수") AS "세션수",
        TRY_TO_NUMBER("페이지뷰") AS "페이지뷰",
        TRY_TO_NUMBER("활성사용자수") AS "활성사용자수",
        TRY_TO_NUMBER("방문수") AS "방문수",
        TRY_TO_NUMBER("이벤트수") AS "이벤트수"
    FROM GN_DW.BRONZE.FACT_GA_VISITS_TOTAL;

    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_GA_VISITS_PC AS
    SELECT
        "페이지경로", "회원ID",
        TRY_TO_NUMBER("세션수") AS "세션수",
        TRY_TO_NUMBER("페이지뷰") AS "페이지뷰",
        TRY_TO_NUMBER("활성사용자수") AS "활성사용자수",
        TRY_TO_NUMBER("방문수") AS "방문수",
        TRY_TO_NUMBER("이벤트수") AS "이벤트수"
    FROM GN_DW.BRONZE.FACT_GA_VISITS_PC;

    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_GA_VISITS_MOBILE AS
    SELECT
        "페이지경로", "이벤트이름", "회원ID",
        TRY_TO_NUMBER("세션수") AS "세션수",
        TRY_TO_NUMBER("페이지뷰") AS "페이지뷰",
        TRY_TO_NUMBER("활성사용자수") AS "활성사용자수",
        TRY_TO_NUMBER("방문수") AS "방문수",
        TRY_TO_NUMBER("이벤트수") AS "이벤트수"
    FROM GN_DW.BRONZE.FACT_GA_VISITS_MOBILE;

    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_GA_VISITS_APP AS
    SELECT
        "페이지경로", "이벤트이름", "회원ID",
        TRY_TO_NUMBER("세션수") AS "세션수",
        TRY_TO_NUMBER("페이지뷰") AS "페이지뷰",
        TRY_TO_NUMBER("활성사용자수") AS "활성사용자수",
        TRY_TO_NUMBER("방문수") AS "방문수",
        TRY_TO_NUMBER("이벤트수") AS "이벤트수"
    FROM GN_DW.BRONZE.FACT_GA_VISITS_APP;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_GA_VISITS_TOTAL;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_GA_VISITS', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows (TOTAL)';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_GA_VISITS', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_GA_FEEDBACK
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_GA_FEEDBACK()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_GA_FEEDBACK_PAGE AS
    SELECT
        "페이지경로쿼리",
        TRY_TO_NUMBER("세션수") AS "세션수",
        TRY_TO_NUMBER("페이지뷰") AS "페이지뷰",
        TRY_TO_NUMBER("이벤트수") AS "이벤트수",
        TRY_TO_DOUBLE("이탈률") AS "이탈률",
        TRY_TO_DOUBLE("참여율") AS "참여율",
        TRY_TO_DOUBLE("평균세션시간") AS "평균세션시간"
    FROM GN_DW.BRONZE.FACT_GA_FEEDBACK_PAGE;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_GA_FEEDBACK_PAGE;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_GA_FEEDBACK', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_GA_FEEDBACK', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_DIM_ORG
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_DIM_ORG()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.DIM_ORG_CODE AS
    SELECT DISTINCT
        TRIM("부서코드") AS "부서코드",
        TRIM("부서명") AS "부서명",
        "부서경로",
        TRIM("상위부서코드") AS "상위부서코드"
    FROM GN_DW.BRONZE.DIM_ORG_CODE
    WHERE "부서코드" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.DIM_ORG_CODE;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_ORG', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_ORG', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_DIM_TEMP_MATCH
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_DIM_TEMP_MATCH()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.DIM_TEMP_TO_REGULAR_MATCH AS
    SELECT
        "회원번호(정기)",
        "회원번호(일시)",
        "전환일",
        TRY_TO_DATE("전환일") AS "전환일자"
    FROM GN_DW.BRONZE.DIM_TEMP_TO_REGULAR_MATCH
    WHERE "회원번호(정기)" IS NOT NULL;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.DIM_TEMP_TO_REGULAR_MATCH;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_TEMP_MATCH', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_DIM_TEMP_MATCH', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_DRTV (BROADCAST_EFF + MONTHLY_DEV)
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_DRTV()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_DRTV_BROADCAST_EFF AS
    SELECT
        "채널", "요일", "방송일자", "시간대", "주중/토/일",
        "프로그램 시작시간", "편성명", CM, "CM위치", "광고 시작시간",
        TRY_TO_DOUBLE("광고시청률") AS "광고시청률",
        "광고종료시간", "Spot Type",
        TRY_TO_NUMBER("횟수") AS "횟수",
        TRY_TO_NUMBER("초수") AS "초수",
        TRY_TO_NUMBER("실구매광고비(원)") AS "실구매광고비(원)",
        TRY_TO_NUMBER("인입콜") AS "인입콜",
        TRY_TO_NUMBER(CPC) AS CPC,
        "소재", "CRM(세부캠페인)명칭", "소재 일관화", "주차", "요일2",
        "방송월", "채널사 유형", "해당연도"
    FROM GN_DW.BRONZE.FACT_DRTV_BROADCAST_EFF;

    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_DRTV_MONTHLY_DEV AS
    SELECT * FROM GN_DW.BRONZE.FACT_DRTV_MONTHLY_DEV;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_DRTV_BROADCAST_EFF;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DRTV', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows (BROADCAST_EFF)';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DRTV', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_DIGITAL_DEV
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_DIGITAL_DEV()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_DIGITAL_MONTHLY_DEV AS
    SELECT * FROM GN_DW.BRONZE.FACT_DIGITAL_MONTHLY_DEV;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_DIGITAL_MONTHLY_DEV;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DIGITAL_DEV', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_DIGITAL_DEV', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_RETRANSMIT (BROADCAST_CONV + MONTHLY_DEV)
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_RETRANSMIT()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_RETRANSMIT_BROADCAST_CONV AS
    SELECT * FROM GN_DW.BRONZE.FACT_RETRANSMIT_BROADCAST_CONV;

    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_RETRANSMIT_MONTHLY_DEV AS
    SELECT * FROM GN_DW.BRONZE.FACT_RETRANSMIT_MONTHLY_DEV;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_RETRANSMIT_BROADCAST_CONV;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_RETRANSMIT', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows (BROADCAST_CONV)';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_RETRANSMIT', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_MARKETING_SEND
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_MARKETING_SEND()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_MARKETING_SEND_NEW AS
    SELECT
        "순번",
        "발송구분(대)", "발송구분(중)", "발송구분(소)", "제목",
        TRY_TO_NUMBER("총건수") AS "총건수",
        TRY_TO_NUMBER("성공건수") AS "성공건수",
        "회원번호",
        TRY_TO_TIMESTAMP("발송일시") AS "발송일시",
        "발송상태", "대체발송", "등록일",
        TRY_TO_DOUBLE("성공률(%)") AS "성공률",
        "브랜드", "상위캠페인"
    FROM GN_DW.BRONZE.FACT_MARKETING_SEND_NEW;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_MARKETING_SEND_NEW;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_MARKETING_SEND', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_MARKETING_SEND', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.1 SP_REFINE_FACT_TEMP_DONATION
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_REFINE_FACT_TEMP_DONATION()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    CREATE OR REPLACE TABLE GN_DW.SILVER.FACT_TEMP_MEMBER_DONATION AS
    SELECT
        "일시회원번호",
        COALESCE("후원금액", 0) AS "후원금액",
        "후원일",
        TRY_TO_DATE("후원일") AS "후원일자",
        "실적부서코드",
        "실적부서명",
        "세부캠페인코드",
        "세부캠페인명"
    FROM GN_DW.BRONZE.FACT_TEMP_MEMBER_DONATION;

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.SILVER.FACT_TEMP_MEMBER_DONATION;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_TEMP_DONATION', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: ' || v_row_count || ' rows';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFINE_FACT_TEMP_DONATION', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.2 SP_REFRESH_FORECAST_DATA
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.GOLD.SP_REFRESH_FORECAST_DATA()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_row_count NUMBER;
BEGIN
    -- 1) 학습 데이터 생성 (SILVER 기반)
    CREATE OR REPLACE TABLE GN_DW.GOLD.FORECAST_TRAINING_DATA AS
    SELECT
        TRY_TO_DATE(LEFT(TO_VARCHAR("후원신청일"), 6) || '01', 'YYYYMMDD') AS MONTH_DATE,
        "브랜드" AS BRAND,
        COUNT(*) AS DEV_COUNT,
        SUM("금액") AS TOTAL_AMOUNT,
        AVG("금액") AS AVG_PAYMENT
    FROM GN_DW.SILVER.FACT_MEMBER_DEV_ALL
    WHERE "개발구분" IN ('신규', '증액', '재후원')
      AND "후원신청일" IS NOT NULL
    GROUP BY LEFT(TO_VARCHAR("후원신청일"), 6), "브랜드";

    CREATE OR REPLACE TABLE GN_DW.GOLD.TRAIN_DEV_COUNT AS
    SELECT MONTH_DATE, BRAND, DEV_COUNT FROM GN_DW.GOLD.FORECAST_TRAINING_DATA
    WHERE MONTH_DATE IS NOT NULL AND BRAND IS NOT NULL;

    CREATE OR REPLACE TABLE GN_DW.GOLD.TRAIN_AVG_PAYMENT AS
    SELECT MONTH_DATE, BRAND, AVG_PAYMENT FROM GN_DW.GOLD.FORECAST_TRAINING_DATA
    WHERE MONTH_DATE IS NOT NULL AND BRAND IS NOT NULL;

    -- 2) 개발건수 예측 모델 학습 (브랜드별 다중 시리즈)
    CREATE OR REPLACE SNOWFLAKE.ML.FORECAST GN_DW.GOLD.FORECAST_MODEL_DEV_COUNT(
        INPUT_DATA => TABLE(
            SELECT TO_VARIANT(BRAND) AS BRAND,
                   MONTH_DATE::TIMESTAMP_NTZ AS MONTH_DATE,
                   DEV_COUNT::FLOAT AS DEV_COUNT
            FROM GN_DW.GOLD.TRAIN_DEV_COUNT
        ),
        SERIES_COLNAME => 'BRAND',
        TIMESTAMP_COLNAME => 'MONTH_DATE',
        TARGET_COLNAME => 'DEV_COUNT',
        CONFIG_OBJECT => {'on_error': 'skip', 'evaluate': FALSE}
    );

    -- 3) 개발건수 예측 결과 저장 (향후 6개월)
    CREATE OR REPLACE TABLE GN_DW.GOLD.FORECAST_DEV_COUNT_RESULT AS
    SELECT * FROM TABLE(GN_DW.GOLD.FORECAST_MODEL_DEV_COUNT!FORECAST(FORECASTING_PERIODS => 6));

    -- 4) 평균납입액 예측 모델 학습/예측
    CREATE OR REPLACE SNOWFLAKE.ML.FORECAST GN_DW.GOLD.FORECAST_MODEL_AVG_PAYMENT(
        INPUT_DATA => TABLE(
            SELECT TO_VARIANT(BRAND) AS BRAND,
                   MONTH_DATE::TIMESTAMP_NTZ AS MONTH_DATE,
                   AVG_PAYMENT::FLOAT AS AVG_PAYMENT
            FROM GN_DW.GOLD.TRAIN_AVG_PAYMENT
        ),
        SERIES_COLNAME => 'BRAND',
        TIMESTAMP_COLNAME => 'MONTH_DATE',
        TARGET_COLNAME => 'AVG_PAYMENT',
        CONFIG_OBJECT => {'on_error': 'skip', 'evaluate': FALSE}
    );

    CREATE OR REPLACE TABLE GN_DW.GOLD.FORECAST_AVG_PAYMENT_RESULT AS
    SELECT * FROM TABLE(GN_DW.GOLD.FORECAST_MODEL_AVG_PAYMENT!FORECAST(FORECASTING_PERIODS => 6));

    SELECT COUNT(*) INTO v_row_count FROM GN_DW.GOLD.FORECAST_TRAINING_DATA;
    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFRESH_FORECAST_DATA', 'SUCCESS', :v_row_count);
    RETURN 'SUCCESS: training=' || v_row_count || ' rows, forecast 6 periods generated';
EXCEPTION
    WHEN OTHER THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_REFRESH_FORECAST_DATA', 'ERROR', 0, SQLERRM);
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

------------------------------------------------------
-- 4.3 SP_RUN_ALL_REFINEMENT (오케스트레이션)
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_RUN_ALL_REFINEMENT()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_result VARCHAR;
    v_errors VARCHAR DEFAULT '';
BEGIN
    -- DIM 정제 (FACT보다 먼저)
    CALL GN_DW.SILVER.SP_REFINE_DIM_CAMPAIGN() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_DIM_MEMBER() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_DIM_ORG() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_DIM_TEMP_MATCH() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    -- FACT 정제
    CALL GN_DW.SILVER.SP_REFINE_FACT_PAYMENT() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_MEMBER_DEV() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_DISCONTINUED() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_DIGITAL_AD() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_SMS() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_AD_GA() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_AD_META() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_GA_VISITS() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_GA_FEEDBACK() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_DRTV() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_DIGITAL_DEV() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_RETRANSMIT() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_MARKETING_SEND() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    CALL GN_DW.SILVER.SP_REFINE_FACT_TEMP_DONATION() INTO v_result;
    IF (LEFT(v_result, 5) = 'ERROR') THEN v_errors := v_errors || v_result || '; '; END IF;

    IF (LENGTH(v_errors) > 0) THEN
        RETURN 'COMPLETED WITH ERRORS: ' || v_errors;
    ELSE
        RETURN 'ALL REFINEMENT COMPLETED SUCCESSFULLY';
    END IF;
END;
$$;

------------------------------------------------------
-- 4.3 SP_VALIDATE_BRONZE_DATA (게이팅: 임계 위반 시 예외 발생 → 태스크 실패)
------------------------------------------------------
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_VALIDATE_BRONZE_DATA()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_violations NUMBER DEFAULT 0;
    v_detail VARCHAR DEFAULT '';
    validation_failed EXCEPTION (-20001, 'BRONZE 데이터 검증 실패: 임계 위반으로 정제 파이프라인을 중단합니다.');
BEGIN
    -- 임계 기준: row count = 0 (적재 누락) 또는 핵심키 NULL 비율 > 5%
    SELECT
        COUNT(*),
        COALESCE(LISTAGG(TABLE_NAME || '(rows=' || ROW_COUNT || ', null_key=' || COALESCE(TO_VARCHAR(NULL_KEY_PCT), 'NA') || '%)', '; '), '')
    INTO v_violations, v_detail
    FROM (
        SELECT 'DIM_CAMPAIGN_CODE' AS TABLE_NAME, COUNT(*) AS ROW_COUNT,
               ROUND(SUM(CASE WHEN "세부캠페인코드" IS NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS NULL_KEY_PCT
        FROM GN_DW.BRONZE.DIM_CAMPAIGN_CODE
        UNION ALL
        SELECT 'DIM_MEMBER_ATTRIBUTE', COUNT(*),
               ROUND(SUM(CASE WHEN "회원번호" IS NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1)
        FROM GN_DW.BRONZE.DIM_MEMBER_ATTRIBUTE
        UNION ALL
        SELECT 'FACT_PAYMENT_HISTORY', COUNT(*),
               ROUND(SUM(CASE WHEN "회원번호" IS NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1)
        FROM GN_DW.BRONZE.FACT_PAYMENT_HISTORY
        UNION ALL
        SELECT 'FACT_MEMBER_DEV_ALL', COUNT(*),
               ROUND(SUM(CASE WHEN "회원번호" IS NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1)
        FROM GN_DW.BRONZE.FACT_MEMBER_DEV_ALL
        UNION ALL
        SELECT 'FACT_DISCONTINUED_MEMBER', COUNT(*),
               ROUND(SUM(CASE WHEN "회원번호" IS NULL THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1)
        FROM GN_DW.BRONZE.FACT_DISCONTINUED_MEMBER
    )
    WHERE ROW_COUNT = 0 OR NULL_KEY_PCT > 5;

    IF (v_violations > 0) THEN
        CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_VALIDATE_BRONZE_DATA', 'ERROR', 0, :v_detail);
        RAISE validation_failed;
    END IF;

    CALL GN_DW.SILVER.SP_LOG_ETL_STATUS('SP_VALIDATE_BRONZE_DATA', 'SUCCESS', 0, 'All BRONZE checks passed');
    RETURN 'VALIDATION PASSED';
END;
$$;
