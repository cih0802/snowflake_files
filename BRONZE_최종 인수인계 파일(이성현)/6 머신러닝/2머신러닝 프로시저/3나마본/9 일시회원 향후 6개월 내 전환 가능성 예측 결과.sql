-- =============================================================================
-- 프로시져: 일시회원 -> 정기회원 전환 확율 예측 프로시져
-- 파라미터: 없음. 실행시점마다 학습데이터 결정 됨.
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 일시회원자중 6개월내 정기 후원자로 전환활 확인이 높은 회원 : 나마본16
-- GN_DW.ML.SP_ONCE_TO_FDRM_CONVERSION_6M
-- 일시회원 정기회원 전환 가능성 예측
-- 기준월을 입력받아 일시회원의 가입 후 후원·서비스 이용·웹 행동 데이터를 기반으로 가입 후 6개월 이내 정기회원 전환 여부를 예측하는 머신러닝 모델을 학습하고 예측 결과를 산출한다.
-- 일시회원의 가입일과 정기회원 전환일을 기준으로 **가입 후 180일 이내 정기회원으로 전환한 경우를 CONVERSION_YN=1**로 정의하여 학습 타겟을 구성한다.
-- 가입월부터 가입 후 5개월까지 월별 스냅샷을 생성하고, 전환 회원은 전환월까지만 데이터를 구성하여 월별 후원 및 행동 특성을 생성한다.
-- 일시후원 횟수·금액·평균·최대금액, 행사·이메일·메시지·우편물·이벤트 등의 서비스 이용 정보와 세션 수, 페이지뷰, 구매, 결제시작, 폼 제출, 스크롤, 참여시간 등 웹 행동 데이터를 주요 예측 피처로 활용한다.
-- 구성된 데이터를 기반으로 Snowflake Classification 모델을 학습하고, 학습된 모델을 이용하여 향후 6개월 내 정기회원 전환 가능성 및 예측 결과를 산출한다.
-- 예측 결과는 GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION 테이블에 기준월 및 회원번호별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_ONCE_TO_FDRM_CONVERSION_6M(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_ONCE_TO_FDRM_CONVERSION_6M';
    
    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터셋 구성 (회원 단위, 증액 타겟)
        -- =============================================================================
        
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_ONCE_TO_FDRM_CONVERSION_6M AS
        WITH TARGET AS (
            /* ============================================================
               1. 학습 대상 회원 및 전환 여부
               ============================================================ */
            SELECT
                a.ONCE_MBER_NO,
                a.FRST_REGIST_DT AS ONCE_JOIN_DT,
                b.FRST_REGIST_DT AS CONVERSION_DT,
                CASE
                    WHEN b.FRST_REGIST_DT > a.FRST_REGIST_DT
                     AND b.FRST_REGIST_DT <= DATEADD(DAY, 180, a.FRST_REGIST_DT)
                    THEN 1
                    ELSE 0
                END AS CONVERSION_YN, 
                CASE
                    WHEN a.FRST_REGIST_DT <= DATEADD(DAY, -180, CURRENT_DATE()) OR CONVERSION_YN = 1 THEN 'TRAIN'
                    ELSE 'SCORE'
                END 
                AS DATA_TYPE
            FROM GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO a
            LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DT_DTLS b
                ON a.ONCE_MBER_NO = b.ONCE_MBER_NO
            /* 가입 후 6개월이 지나 라벨이 확정된 회원만 학습 대상 */
            WHERE 
                a.FRST_REGIST_DT >= '2024-01-01'
        ),
        /* ============================================================
           2. 월별 스냅샷 생성
              - 가입월 = 1개월차
              - 가입 후 6개월차까지
              - 전환 회원은 전환월까지만
           ============================================================ */
        MONTHLY_TARGET AS (
            SELECT
                T.ONCE_MBER_NO,
                T.ONCE_JOIN_DT,
                T.CONVERSION_DT,
                T.CONVERSION_YN,
                T.DATA_TYPE,
                DATEADD(
                    MONTH,
                    M.MONTH_SEQ,
                    DATE_TRUNC('MONTH', T.ONCE_JOIN_DT)
                ) AS STDR_MONTH
            FROM TARGET T
            CROSS JOIN (
                SELECT 0 AS MONTH_SEQ
                UNION ALL SELECT 1
                UNION ALL SELECT 2
                UNION ALL SELECT 3
                UNION ALL SELECT 4
                UNION ALL SELECT 5
            ) M
            WHERE
                /* 가입월 ~ 가입 후 5개월 = 총 6개 월 */
                DATEADD(
                    MONTH,
                    M.MONTH_SEQ,
                    DATE_TRUNC('MONTH', T.ONCE_JOIN_DT)
                ) <= TO_DATE(:V_STDR_MT || '01', 'YYYYMMDD')
                
                /* 전환월까지만 생성 */
                AND (
                    T.CONVERSION_DT IS NULL
                    OR
                    DATEADD(
                        MONTH,
                        M.MONTH_SEQ,
                        DATE_TRUNC('MONTH', T.ONCE_JOIN_DT)
                    ) <= DATE_TRUNC('MONTH', T.CONVERSION_DT)
                )
        ),
        ONCE_BQ AS (
            SELECT DISTINCT
                b.ONCE_MBER_NO,
                a.USER_PSEUDO_ID,
                a.EP_GA_SESSION_ID
            FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA a
            INNER JOIN TARGET b
                ON COALESCE(a.USER_ID, a.UP_MEMBER_ID, a.UP_USER_ID) = b.ONCE_MBER_NO
            ORDER BY
                a.USER_PSEUDO_ID,
                a.EP_GA_SESSION_ID
        ),
        BQ_MONTHLY AS (
            SELECT
                b.ONCE_MBER_NO,
                LEFT(a.EVENT_DATE, 6) AS STDR_MT,
                COUNT(
                    DISTINCT a.USER_PSEUDO_ID || '_' || a.EP_GA_SESSION_ID
                ) AS SESSION_CNT,
                COUNT(*) AS BQ_EVENT_CNT,
        
                COUNT(
                    DISTINCT a.EVENT_DATE
                ) AS ACTIVE_DAY_CNT,
                SUM(
                    CASE
                        WHEN a.EVENT_NAME = 'page_view'
                        THEN 1 ELSE 0
                    END
                ) AS PAGE_VIEW_CNT,
                SUM(
                    CASE
                        WHEN a.EVENT_NAME = 'purchase'
                        THEN 1 ELSE 0
                    END
                ) AS PURCHASE_CNT,
                SUM(
                    CASE
                        WHEN a.EVENT_NAME = 'begin_checkout'
                        THEN 1 ELSE 0
                    END
                ) AS BEGIN_CHECKOUT_CNT,
                SUM(
                    CASE
                        WHEN a.EVENT_NAME = 'form_submit'
                        THEN 1 ELSE 0
                    END
                ) AS FORM_SUBMIT_CNT,
                SUM(
                    CASE
                        WHEN a.EVENT_NAME = 'scroll'
                        THEN 1 ELSE 0
                    END
                ) AS SCROLL_CNT,
                SUM(
                    COALESCE(a.EP_ENGAGEMENT_TIME_MSEC, 0)
                ) / 1000.0 AS ENGAGEMENT_TIME_SEC,
                COUNT(
                    DISTINCT CASE
                        WHEN a.EP_SESSION_ENGAGED = '1'
                        THEN a.USER_PSEUDO_ID || '_' || a.EP_GA_SESSION_ID
                    END
                ) AS ENGAGED_SESSION_CNT,
                COUNT(
                    DISTINCT CASE
                        WHEN a.DEVICE_CATEGORY = 'mobile'
                        THEN a.USER_PSEUDO_ID || '_' || a.EP_GA_SESSION_ID
                    END
                ) AS MOBILE_SESSION_CNT,
        
                COUNT(
                    DISTINCT CASE
                        WHEN a.DEVICE_CATEGORY = 'desktop'
                        THEN a.USER_PSEUDO_ID || '_' || a.EP_GA_SESSION_ID
                    END
                ) AS DESKTOP_SESSION_CNT
            FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA a
            INNER JOIN ONCE_BQ b
                ON a.USER_PSEUDO_ID = b.USER_PSEUDO_ID
               AND a.EP_GA_SESSION_ID = b.EP_GA_SESSION_ID
            GROUP BY
                b.ONCE_MBER_NO,
                LEFT(a.EVENT_DATE, 6)
        )
        SELECT
            a.ONCE_MBER_NO,
            TO_VARCHAR(a.STDR_MONTH, 'YYYYMM') AS STDR_MT,
            a.ONCE_JOIN_DT,
            a.CONVERSION_DT,
            a.CONVERSION_YN,
            a.DATA_TYPE,
            b.ONCE_DNTN_CNT,
            b.ONCE_DNTN_AMT,
            b.ONCE_DNTN_AVG_AMT, 
            b.ONCE_DNTN_MAX_AMT,
            c.SERVICE_CNT,
            c.CRMN_CNT,
            c.EMAIL_CNT,
            c.MESSAGE_CNT,
            c.PSTMTR_CNT,
            c.EVENT_CNT,
            d.SESSION_CNT,
            d.BQ_EVENT_CNT,
            d.ACTIVE_DAY_CNT,
            d.PAGE_VIEW_CNT,
            d.PURCHASE_CNT,
            d.BEGIN_CHECKOUT_CNT,
            d.FORM_SUBMIT_CNT,
            d.SCROLL_CNT,
            d.ENGAGEMENT_TIME_SEC,
            d.ENGAGED_SESSION_CNT,
            d.MOBILE_SESSION_CNT,
            d.DESKTOP_SESSION_CNT
        FROM MONTHLY_TARGET a
            LEFT OUTER JOIN (
                SELECT
                    ONCE_MBER_NO,
                    TO_VARCHAR(PAY_DE, 'YYYYMM') AS STDR_MT,
                    -- 기부 횟수
                    COUNT(*) AS ONCE_DNTN_CNT,
                    -- 기부 금액
                    SUM(PAY_AMT) AS ONCE_DNTN_AMT,
                    -- 평균 기부 금액
                    AVG(PAY_AMT) AS ONCE_DNTN_AVG_AMT,
                    -- 최대 기부 금액
                    MAX(PAY_AMT) AS ONCE_DNTN_MAX_AMT
                FROM GN_DW.BRONZE_CRM.TM_PM_DNTN_DTLS
                WHERE USE_YN = 'Y'
                GROUP BY
                    ONCE_MBER_NO,
                    TO_VARCHAR(PAY_DE, 'YYYYMM')
            ) b ON a.ONCE_MBER_NO = b.ONCE_MBER_NO AND TO_VARCHAR(a.STDR_MONTH, 'YYYYMM') = b.STDR_MT
            LEFT OUTER JOIN (
                -- 일시후원별 서비스 정보. 정보 있으면 서비스 제공한 것이다. 이메일, 메시지의 경우 
                SELECT
                    MBER_NO,
                    LEFT(SVR_DT, 6) AS STDR_MT,
                    /* 전체 서비스 제공 건수 */
                    COUNT(*) AS SERVICE_CNT,
                    /* SVC_TYPE별 제공 건수 */
                    SUM(CASE WHEN SVC_TYPE = '행사' THEN 1 ELSE 0 END) AS CRMN_CNT,
                    SUM(CASE WHEN SVC_TYPE = '이메일' THEN 1 ELSE 0 END) AS EMAIL_CNT,
                    SUM(CASE WHEN SVC_TYPE = '메세지' THEN 1 ELSE 0 END) AS MESSAGE_CNT,
                    SUM(CASE WHEN SVC_TYPE = '우편물' THEN 1 ELSE 0 END) AS PSTMTR_CNT,
                    SUM(CASE WHEN SVC_TYPE = '이벤트' THEN 1 ELSE 0 END) AS EVENT_CNT
                FROM GN_DW.ML.MBER_SERVICE_INFO
                WHERE SVR_DT IS NOT NULL
                GROUP BY
                    MBER_NO,
                    LEFT(SVR_DT, 6)
            ) c ON a.ONCE_MBER_NO = c.MBER_NO AND TO_VARCHAR(a.STDR_MONTH, 'YYYYMM') = c.STDR_MT
            LEFT OUTER JOIN BQ_MONTHLY d ON a.ONCE_MBER_NO = d.ONCE_MBER_NO AND TO_VARCHAR(a.STDR_MONTH, 'YYYYMM') = d.STDR_MT
        ORDER BY
            a.ONCE_MBER_NO,
            TO_VARCHAR(a.STDR_MONTH, 'YYYYMM');

        -- =============================================================================
        -- STEP 2: 학습용 뷰 + 모델 학습
        -- =============================================================================
        CREATE OR REPLACE VIEW GN_DW.ML.V_TRAIN_ONCE_CONVERSION AS
        SELECT
            -- 기부 피처
            COALESCE(ONCE_DNTN_CNT, 0)       AS ONCE_DNTN_CNT,
            COALESCE(ONCE_DNTN_AMT, 0)       AS ONCE_DNTN_AMT,
            COALESCE(ONCE_DNTN_AVG_AMT, 0)   AS ONCE_DNTN_AVG_AMT,
            COALESCE(ONCE_DNTN_MAX_AMT, 0)   AS ONCE_DNTN_MAX_AMT,
            -- 서비스 피처
            COALESCE(SERVICE_CNT, 0)          AS SERVICE_CNT,
            COALESCE(CRMN_CNT, 0)            AS CRMN_CNT,
            COALESCE(EMAIL_CNT, 0)           AS EMAIL_CNT,
            COALESCE(MESSAGE_CNT, 0)         AS MESSAGE_CNT,
            COALESCE(PSTMTR_CNT, 0)          AS PSTMTR_CNT,
            COALESCE(EVENT_CNT, 0)           AS EVENT_CNT,
            -- 웹 행동 피처
            COALESCE(SESSION_CNT, 0)          AS SESSION_CNT,
            COALESCE(BQ_EVENT_CNT, 0)        AS BQ_EVENT_CNT,
            COALESCE(ACTIVE_DAY_CNT, 0)      AS ACTIVE_DAY_CNT,
            COALESCE(PAGE_VIEW_CNT, 0)       AS PAGE_VIEW_CNT,
            COALESCE(PURCHASE_CNT, 0)        AS PURCHASE_CNT,
            COALESCE(BEGIN_CHECKOUT_CNT, 0)  AS BEGIN_CHECKOUT_CNT,
            COALESCE(FORM_SUBMIT_CNT, 0)     AS FORM_SUBMIT_CNT,
            COALESCE(SCROLL_CNT, 0)          AS SCROLL_CNT,
            COALESCE(ENGAGEMENT_TIME_SEC, 0) AS ENGAGEMENT_TIME_SEC,
            COALESCE(ENGAGED_SESSION_CNT, 0) AS ENGAGED_SESSION_CNT,
            COALESCE(MOBILE_SESSION_CNT, 0)  AS MOBILE_SESSION_CNT,
            COALESCE(DESKTOP_SESSION_CNT, 0) AS DESKTOP_SESSION_CNT,
            -- 타겟
            CONVERSION_YN
        FROM GN_DW.ML.ML_TRAIN_DATA_ONCE_TO_FDRM_CONVERSION_6M;
      
       -- =============================================================================
        -- STEP 4: 예측 실행 (테이블 없으면 생성+COMMENT, 있으면 DELETE 후 INSERT)
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.ONCE_TO_FDRM_CLASSIFIER(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'GN_DW.ML.V_TRAIN_ONCE_CONVERSION'),
            TARGET_COLNAME => 'CONVERSION_YN',
            CONFIG_OBJECT => {'evaluate': TRUE}
        );
        
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION (
            STDR_MT VARCHAR COMMENT '기준월 (YYYYMM)',
            ONCE_MBER_NO VARCHAR COMMENT '회원번호',
            PREDICT VARIANT COMMENT '예측결과'
        )
        COMMENT = '일시회원 향후 6개월 내 전환 가능성 예측 결과';
        
        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 결과 INSERT
        INSERT INTO GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION
        SELECT
            :V_STDR_MT,
            t.ONCE_MBER_NO,
            pred.PREDICT
        FROM GN_DW.ML.ML_TRAIN_DATA_ONCE_TO_FDRM_CONVERSION_6M t,
        LATERAL (
            SELECT
                GN_DW.ML.ONCE_TO_FDRM_CLASSIFIER!PREDICT(
                    INPUT_DATA => OBJECT_CONSTRUCT(
                        'ONCE_DNTN_CNT',       COALESCE(t.ONCE_DNTN_CNT, 0),
                        'ONCE_DNTN_AMT',       COALESCE(t.ONCE_DNTN_AMT, 0),
                        'ONCE_DNTN_AVG_AMT',   COALESCE(t.ONCE_DNTN_AVG_AMT, 0),
                        'ONCE_DNTN_MAX_AMT',   COALESCE(t.ONCE_DNTN_MAX_AMT, 0),
                        'SERVICE_CNT',         COALESCE(t.SERVICE_CNT, 0),
                        'CRMN_CNT',            COALESCE(t.CRMN_CNT, 0),
                        'EMAIL_CNT',           COALESCE(t.EMAIL_CNT, 0),
                        'MESSAGE_CNT',         COALESCE(t.MESSAGE_CNT, 0),
                        'PSTMTR_CNT',          COALESCE(t.PSTMTR_CNT, 0),
                        'EVENT_CNT',           COALESCE(t.EVENT_CNT, 0),
                        'SESSION_CNT',         COALESCE(t.SESSION_CNT, 0),
                        'BQ_EVENT_CNT',        COALESCE(t.BQ_EVENT_CNT, 0),
                        'ACTIVE_DAY_CNT',      COALESCE(t.ACTIVE_DAY_CNT, 0),
                        'PAGE_VIEW_CNT',       COALESCE(t.PAGE_VIEW_CNT, 0),
                        'PURCHASE_CNT',        COALESCE(t.PURCHASE_CNT, 0),
                        'BEGIN_CHECKOUT_CNT',  COALESCE(t.BEGIN_CHECKOUT_CNT, 0),
                        'FORM_SUBMIT_CNT',     COALESCE(t.FORM_SUBMIT_CNT, 0),
                        'SCROLL_CNT',          COALESCE(t.SCROLL_CNT, 0),
                        'ENGAGEMENT_TIME_SEC', COALESCE(t.ENGAGEMENT_TIME_SEC, 0),
                        'ENGAGED_SESSION_CNT', COALESCE(t.ENGAGED_SESSION_CNT, 0),
                        'MOBILE_SESSION_CNT',  COALESCE(t.MOBILE_SESSION_CNT, 0),
                        'DESKTOP_SESSION_CNT', COALESCE(t.DESKTOP_SESSION_CNT, 0)
                    )
                ) AS PREDICT
        ) pred
        WHERE t.DATA_TYPE = 'SCORE';

        -- 성공 로그 기록
        INSERT INTO GN_DW.ML.ML_PROCEDURE_LOG (PROC_NAME, STDR_MT, START_TIME, END_TIME, DURATION_SEC, STATUS, ERROR_MSG)
        SELECT 
            :V_PROC_NAME,
            :V_STDR_MT,
            :V_START_TIME,
            CURRENT_TIMESTAMP(),
            DATEDIFF('SECOND', :V_START_TIME, CURRENT_TIMESTAMP()),
            'SUCCESS',
            NULL;
        
        RETURN 'SUCCESS: STDR_MT=' || :V_STDR_MT;
    EXCEPTION
        WHEN OTHER THEN
            LET V_ERR_MSG VARCHAR := SQLERRM;
            -- 실패 로그 기록
            INSERT INTO GN_DW.ML.ML_PROCEDURE_LOG (PROC_NAME, STDR_MT, START_TIME, END_TIME, DURATION_SEC, STATUS, ERROR_MSG)
            SELECT 
                :V_PROC_NAME,
                :V_STDR_MT,
                :V_START_TIME,
                CURRENT_TIMESTAMP(),
                DATEDIFF('SECOND', :V_START_TIME, CURRENT_TIMESTAMP()),
                'FAILED',
                :V_ERR_MSG;

            RETURN 'FAILED: ' || :V_ERR_MSG;
    END;
END;
-- 결과 확인
SELECT 
    a.MBER_NO, a.STDR_MT, a.CONVERSION_YN,
    PREDICT:"class"::STRING,
    ROUND(PREDICT:"probability":"0"::NUMBER(38,18), 5) AS NON_CONVERT_RATE,
    ROUND(PREDICT:"probability":"1"::NUMBER(38,18), 5) AS CONVERT_RATE,
FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION a
ORDER BY CONVERT_RATE DESC;


SELECT 
    b.*,
    PREDICT:"class"::STRING,
    ROUND(PREDICT:"probability":"0"::NUMBER(38,18), 5) AS NON_CONVERT_RATE,
    ROUND(PREDICT:"probability":"1"::NUMBER(38,18), 5) AS CONVERT_RATE,
FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION a
    INNER JOIN GN_DW.ML.ML_TRAIN_DATA_ONCE_TO_FDRM_CONVERSION_6M b ON a.ONCE_MBER_NO = b.ONCE_MBER_NO
ORDER BY CONVERT_RATE DESC;
