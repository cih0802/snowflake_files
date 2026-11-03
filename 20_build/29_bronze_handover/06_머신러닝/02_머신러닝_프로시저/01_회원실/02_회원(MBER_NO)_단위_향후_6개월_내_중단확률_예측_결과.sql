-- =============================================================================
-- 프로시져: 회원 단위 중단 고위험군 예측 (향후 6개월). 
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- GN_DW.ML.SP_MBER_CHURN_6M_PREDICT 프로시저
-- 회원 6개월 중단 예측
-- 기준월을 입력받아 과거 회원 및 후원 데이터를 기반으로 회원 단위 향후 6개월 내 중단 여부를 예측하는 머신러닝 모델을 학습하고 예측 결과를 산출한다.
-- 회원별 활성 후원건 수, 후원금액, 증액·감액·해지·재후원 건수 및 금액, 후원 유지기간, 납입 성공률, 결제수단, 법인/개인 구분 등의 데이터를 활용하여 학습데이터를 구성한다.
-- 기준월 이후 6개월 이내 회원 상태가 중단으로 변경된 경우를 CHURN_6M으로 정의하여 중단 여부를 학습하고, Snowflake Classification 모델을 생성한다.
-- 입력 기준월의 현재 활동 회원을 대상으로 동일한 특성 데이터를 구성하고, 학습된 모델을 이용하여 향후 6개월 내 중단확률 및 예측 결과를 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M 테이블에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_MBER_CHURN_6M_PREDICT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_TRAIN_END VARCHAR := TO_CHAR(DATEADD(MONTH, -6, TO_DATE(:V_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMM');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_MBER_CHURN_6M_PREDICT';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터셋 구성 (회원 단위)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MBER_CHURN_6M AS
        WITH 
        MBER_DVLP AS (
            SELECT 
                STDR_MT, MBER_NO,
                COUNT(DISTINCT SPNSR_BSNS_ID) AS ACTIVE_SPNSR_CNT,
                SUM(STDR_MT_SPNSR_AMT) AS TOTAL_SPNSR_AMT,
                SUM(NEW_CNT) AS TOTAL_NEW_CNT,
                SUM(INC_CNT) AS TOTAL_INC_CNT,
                SUM(DEC_CNT) AS TOTAL_DEC_CNT,
                SUM(RE_CNT) AS TOTAL_RE_CNT,
                SUM(CANCL_CNT) AS TOTAL_CANCL_CNT,
                SUM(INC_SPNSR_AMT) AS TOTAL_INC_AMT,
                SUM(DEC_SPNSR_AMT) AS TOTAL_DEC_AMT,
                SUM(CANCL_SPNSR_AMT) AS TOTAL_CANCL_AMT,
                DIV0NULL(ABS(SUM(CANCL_SPNSR_AMT)), SUM(STDR_MT_SPNSR_AMT)) AS DNST_RT
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
            GROUP BY STDR_MT, MBER_NO
        ),
        MBER_STAT AS (
            SELECT STDR_MT, MBER_NO, STDR_MT_MBER_STAT_CD, MONTHS_SINCE_JOIN
            FROM GN_DW.ML.MBER_MONTHLY_INFO
            QUALIFY ROW_NUMBER() OVER (PARTITION BY MBER_NO, STDR_MT ORDER BY STDR_MT) = 1
        ),
        PAY_FEATURES AS (
            SELECT 
                LEFT(MBRFEE_MT, 6) AS STDR_MT,
                MBER_NO,
                COUNT(*) AS PAY_REQ_CNT,
                SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END) AS PAY_SUC_CNT,
                DIV0NULL(SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE,
                SUM(RGR_REQ_AMT) AS TOTAL_REQ_AMT,
                SUM(RGR_PAY_AMT) AS TOTAL_PAY_AMT
            FROM GN_DW.ML.MBRFEE_PAY_DTLS
            GROUP BY LEFT(MBRFEE_MT, 6), MBER_NO
        ),
        SETLE_FEATURES AS (
            SELECT STDR_MT, MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD
            FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
            QUALIFY ROW_NUMBER() OVER (PARTITION BY MBER_NO, STDR_MT ORDER BY STDR_MT_SETLE_CD) = 1
        ),
        CHURN_EVENTS AS (
            SELECT MBER_NO, STDR_MT AS CHURN_MT
            FROM GN_DW.ML.MBER_MONTHLY_INFO
            WHERE STDR_MT_MBER_STAT_CD = ''12''
        ),
        CHURN_FLAG AS (
            SELECT 
                m.MBER_NO, m.STDR_MT,
                MAX(CASE WHEN ce.CHURN_MT IS NOT NULL THEN 1 ELSE 0 END) AS CHURN_6M
            FROM (
                SELECT DISTINCT STDR_MT, MBER_NO
                FROM GN_DW.ML.MBER_MONTHLY_INFO
                WHERE STDR_MT_MBER_STAT_CD != ''12''
                  AND STDR_MT BETWEEN ''202201'' AND ''' || :V_TRAIN_END || '''
                  AND RIGHT(STDR_MT, 2) IN (''01'', ''04'', ''07'', ''10'')
            ) m
            LEFT JOIN CHURN_EVENTS ce
                ON ce.MBER_NO = m.MBER_NO
               AND ce.CHURN_MT > m.STDR_MT
               AND ce.CHURN_MT <= TO_CHAR(DATEADD(MONTH, 6, TO_DATE(m.STDR_MT || ''01'', ''YYYYMMDD'')), ''YYYYMM'')
            GROUP BY m.MBER_NO, m.STDR_MT
        )
        SELECT 
            cf.STDR_MT, cf.MBER_NO,
            s.STDR_MT_MBER_STAT_CD AS MBER_STAT_CD,
            s.MONTHS_SINCE_JOIN,
            COALESCE(d.ACTIVE_SPNSR_CNT, 0) AS ACTIVE_SPNSR_CNT,
            COALESCE(d.TOTAL_SPNSR_AMT, 0) AS TOTAL_SPNSR_AMT,
            COALESCE(d.TOTAL_INC_CNT, 0) AS TOTAL_INC_CNT,
            COALESCE(d.TOTAL_DEC_CNT, 0) AS TOTAL_DEC_CNT,
            COALESCE(d.TOTAL_CANCL_CNT, 0) AS TOTAL_CANCL_CNT,
            COALESCE(d.TOTAL_INC_AMT, 0) AS TOTAL_INC_AMT,
            COALESCE(d.TOTAL_DEC_AMT, 0) AS TOTAL_DEC_AMT,
            COALESCE(d.TOTAL_CANCL_AMT, 0) AS TOTAL_CANCL_AMT,
            COALESCE(d.DNST_RT, 0) AS DNST_RT,
            COALESCE(p.PAY_RATE, 1) AS PAY_RATE,
            COALESCE(p.PAY_REQ_CNT, 0) AS PAY_REQ_CNT,
            COALESCE(se.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(se.CPR_DIV_CD, ''UNKNOWN'') AS CPR_DIV_CD,
            cf.CHURN_6M
        FROM CHURN_FLAG cf
        LEFT JOIN MBER_STAT s ON cf.MBER_NO = s.MBER_NO AND cf.STDR_MT = s.STDR_MT
        LEFT JOIN MBER_DVLP d ON cf.MBER_NO = d.MBER_NO AND cf.STDR_MT = d.STDR_MT
        LEFT JOIN PAY_FEATURES p ON cf.MBER_NO = p.MBER_NO AND cf.STDR_MT = p.STDR_MT
        LEFT JOIN SETLE_FEATURES se ON cf.MBER_NO = se.MBER_NO AND cf.STDR_MT = se.STDR_MT
        ';

        -- =============================================================================
        -- STEP 2: 학습용 뷰 + 모델 학습
        -- =============================================================================
        CREATE OR REPLACE VIEW GN_DW.ML.ML_TRAIN_DATA_MBER_CHURN_6M_V AS
        SELECT 
            MBER_STAT_CD, MONTHS_SINCE_JOIN, ACTIVE_SPNSR_CNT, TOTAL_SPNSR_AMT,
            TOTAL_INC_CNT, TOTAL_DEC_CNT, TOTAL_CANCL_CNT,
            TOTAL_INC_AMT, TOTAL_DEC_AMT, TOTAL_CANCL_AMT,
            DNST_RT, PAY_RATE, PAY_REQ_CNT, SETLE_CD, CPR_DIV_CD, CHURN_6M
        FROM GN_DW.ML.ML_TRAIN_DATA_MBER_CHURN_6M;

        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.MBER_CHURN_CLASSIFIER_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'GN_DW.ML.ML_TRAIN_DATA_MBER_CHURN_6M_V'),
            TARGET_COLNAME => 'CHURN_6M',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 3: 예측 데이터 구성 (현재 활동 회원)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_ACT_MBER_CHURN_12M AS
        WITH 
        MBER_DVLP AS (
            SELECT 
                STDR_MT, MBER_NO,
                COUNT(DISTINCT SPNSR_BSNS_ID) AS ACTIVE_SPNSR_CNT,
                SUM(STDR_MT_SPNSR_AMT) AS TOTAL_SPNSR_AMT,
                SUM(INC_CNT) AS TOTAL_INC_CNT,
                SUM(DEC_CNT) AS TOTAL_DEC_CNT,
                SUM(CANCL_CNT) AS TOTAL_CANCL_CNT,
                SUM(INC_SPNSR_AMT) AS TOTAL_INC_AMT,
                SUM(DEC_SPNSR_AMT) AS TOTAL_DEC_AMT,
                SUM(CANCL_SPNSR_AMT) AS TOTAL_CANCL_AMT,
                DIV0NULL(ABS(SUM(CANCL_SPNSR_AMT)), SUM(STDR_MT_SPNSR_AMT)) AS DNST_RT
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
            WHERE STDR_MT = ''' || :V_STDR_MT || '''
            GROUP BY STDR_MT, MBER_NO
        ),
        PAY_FEATURES AS (
            SELECT 
                MBER_NO,
                COUNT(*) AS PAY_REQ_CNT,
                DIV0NULL(SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE
            FROM GN_DW.ML.MBRFEE_PAY_DTLS
            WHERE LEFT(MBRFEE_MT, 6) = ''' || :V_STDR_MT || '''
            GROUP BY MBER_NO
        ),
        SETLE_FEATURES AS (
            SELECT MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD
            FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
            WHERE STDR_MT = ''' || :V_STDR_MT || '''
            QUALIFY ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY STDR_MT_SETLE_CD) = 1
        )
        SELECT 
            m.STDR_MT, m.MBER_NO,
            m.STDR_MT_MBER_STAT_CD AS MBER_STAT_CD,
            m.MONTHS_SINCE_JOIN,
            COALESCE(d.ACTIVE_SPNSR_CNT, 0) AS ACTIVE_SPNSR_CNT,
            COALESCE(d.TOTAL_SPNSR_AMT, 0) AS TOTAL_SPNSR_AMT,
            COALESCE(d.TOTAL_INC_CNT, 0) AS TOTAL_INC_CNT,
            COALESCE(d.TOTAL_DEC_CNT, 0) AS TOTAL_DEC_CNT,
            COALESCE(d.TOTAL_CANCL_CNT, 0) AS TOTAL_CANCL_CNT,
            COALESCE(d.TOTAL_INC_AMT, 0) AS TOTAL_INC_AMT,
            COALESCE(d.TOTAL_DEC_AMT, 0) AS TOTAL_DEC_AMT,
            COALESCE(d.TOTAL_CANCL_AMT, 0) AS TOTAL_CANCL_AMT,
            COALESCE(d.DNST_RT, 0) AS DNST_RT,
            COALESCE(p.PAY_RATE, 1) AS PAY_RATE,
            COALESCE(p.PAY_REQ_CNT, 0) AS PAY_REQ_CNT,
            COALESCE(se.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(se.CPR_DIV_CD, ''UNKNOWN'') AS CPR_DIV_CD
        FROM GN_DW.ML.MBER_MONTHLY_INFO m
        LEFT JOIN MBER_DVLP d ON m.MBER_NO = d.MBER_NO AND m.STDR_MT = d.STDR_MT --261006 수정
        LEFT JOIN PAY_FEATURES p ON m.MBER_NO = p.MBER_NO
        LEFT JOIN SETLE_FEATURES se ON m.MBER_NO = se.MBER_NO
        WHERE m.STDR_MT = ''' || :V_STDR_MT || '''
          AND m.STDR_MT_MBER_STAT_CD != ''12''
        ';

        -- =============================================================================
        -- STEP 4: 예측 실행 (테이블 없으면 생성+COMMENT, 있으면 DELETE 후 INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M (
            STDR_MT VARCHAR COMMENT '기준월 (YYYYMM)',
            MBER_NO VARCHAR COMMENT '회원번호',
            PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
        )
        COMMENT = '회원(MBER_NO) 단위 향후 6개월 내 중단확률 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 결과 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            MBER_NO,
            GN_DW.ML.MBER_CHURN_CLASSIFIER_MODEL!PREDICT(
                INPUT_DATA => OBJECT_CONSTRUCT(
                    ''MBER_STAT_CD'', MBER_STAT_CD,
                    ''MONTHS_SINCE_JOIN'', MONTHS_SINCE_JOIN,
                    ''ACTIVE_SPNSR_CNT'', ACTIVE_SPNSR_CNT,
                    ''TOTAL_SPNSR_AMT'', TOTAL_SPNSR_AMT,
                    ''TOTAL_INC_CNT'', TOTAL_INC_CNT,
                    ''TOTAL_DEC_CNT'', TOTAL_DEC_CNT,
                    ''TOTAL_CANCL_CNT'', TOTAL_CANCL_CNT,
                    ''TOTAL_INC_AMT'', TOTAL_INC_AMT,
                    ''TOTAL_DEC_AMT'', TOTAL_DEC_AMT,
                    ''TOTAL_CANCL_AMT'', TOTAL_CANCL_AMT,
                    ''DNST_RT'', DNST_RT,
                    ''PAY_RATE'', PAY_RATE,
                    ''PAY_REQ_CNT'', PAY_REQ_CNT,
                    ''SETLE_CD'', SETLE_CD,
                    ''CPR_DIV_CD'', CPR_DIV_CD
                )
            ) AS PREDICTION
        FROM GN_DW.ML.ML_TRAIN_DATA_ACT_MBER_CHURN_12M
        ';

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

        RETURN 'SUCCESS: STDR_MT=' || :V_STDR_MT || ', TRAIN_END=' || :V_TRAIN_END;

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
