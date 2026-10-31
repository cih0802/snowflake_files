-- =============================================================================
-- 프로시져: 캠페인 카테고리별 후원 중단 12개월 예측
-- 후원건(SPNSR_BSNS_NO) 단위 향후 12개월 내 중단확률 예측 결과를 집계하는 방식으로 사용
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분 초단위)
-- =============================================================================

-- 후원건 12개월 중단 예측
-- 기준월을 입력받아 과거 후원 데이터를 기반으로 후원건별 향후 12개월 내 중단 여부를 예측하는 머신러닝 모델을 학습하고 예측 결과를 산출한다.
-- 과거 후원 이력, 후원금액, 유지기간, 변경·증액·감액·재후원 건수 및 금액, 납입 성공률, 결제수단 등의 데이터를 활용하여 학습데이터를 구성한다.
-- 향후 12개월 내 후원이 중단된 경우를 기준으로 중단 여부(CHURN_12M)를 생성하고, Snowflake Classification 모델을 학습한다.
-- 입력 기준월의 현재 활성 후원건을 대상으로 예측 데이터를 구성하고, 학습된 모델을 이용하여 향후 12개월 내 중단확률 및 예측 결과를 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부와 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CALL GN_DW.ML.SP_SPNSR_CHURN_12M_PREDICT('202606');
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_SPNSR_CHURN_12M_PREDICT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_TRAIN_END VARCHAR := TO_CHAR(DATEADD(MONTH, -12, TO_DATE(:V_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMM');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_SPNSR_CHURN_12M_PREDICT';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터셋 구성
        -- 건수 많아서 분기별.....
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_SPNSR_CHURN_12M AS
        WITH 
        CMPGN_CTGR AS (
            SELECT DISTINCT CMPGN_CTGR_CD
            FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
            WHERE CMPGN_CTGR_CD IS NOT NULL
        ),
        DVLP_FEATURES AS (
            SELECT 
                d.STDR_MT,
                d.MBER_NO,
                d.SPNSR_BSNS_ID,
                d.SPNSR_BSNS_NO,
                d.CMPGN_CTGR_CD,
                d.STDR_MT_DVLP_DIV_CD,
                d.STDR_MT_SPNSR_AMT,
                d.NEW_CNT,
                d.INC_CNT,
                d.DEC_CNT,
                d.RE_CNT,
                --d.CANCL_CNT,
                d.CHN_CNT,
                d.NEW_SPNSR_AMT,
                d.INC_SPNSR_AMT,
                d.DEC_SPNSR_AMT,
                d.CANCL_SPNSR_AMT,
                DATEDIFF(''MONTH'', TO_DATE(d.FIRST_OCCRRNC_DE, ''YYYYMMDD''), TO_DATE(d.STDR_MT || ''01'', ''YYYYMMDD'')) AS TENURE_MONTHS
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT d
            JOIN CMPGN_CTGR c ON d.CMPGN_CTGR_CD = c.CMPGN_CTGR_CD
            WHERE d.STDR_MT_DVLP_DIV_CD NOT IN (''5'')
              AND d.STDR_MT BETWEEN ''202301'' AND ''' || :V_TRAIN_END || '''
              -- AND RIGHT(d.STDR_MT, 2) IN (''01'', ''04'', ''07'', ''10'')
        ),
        CHURN_EVENTS AS (
            SELECT 
                MBER_NO,
                SPNSR_BSNS_ID,
                SPNSR_BSNS_NO,
                STDR_MT AS CHURN_MT
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
            WHERE STDR_MT_DVLP_DIV_CD = ''5''
        ),
        PAY_FEATURES AS (
            SELECT 
                MBER_NO,
                SPNSR_BSNS_ID,
                SPNSR_BSNS_NO,
                LEFT(MBRFEE_MT, 6) AS STDR_MT,
                COUNT(*) AS PAY_CNT,
                SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END) AS PAY_SUC_CNT,
                DIV0NULL(SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE
            FROM GN_DW.ML.MBRFEE_PAY_DTLS
            GROUP BY MBER_NO, SPNSR_BSNS_ID, SPNSR_BSNS_NO, LEFT(MBRFEE_MT, 6)
        ),
        SETLE_FEATURES AS (
            SELECT 
                MBER_NO,
                STDR_MT,
                STDR_MT_SETLE_CD
            FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
        ),
        CHURN_FLAG AS (
            SELECT 
                f.MBER_NO,
                f.SPNSR_BSNS_ID,
                f.SPNSR_BSNS_NO,
                f.STDR_MT,
                MAX(CASE WHEN ce.CHURN_MT IS NOT NULL THEN 1 ELSE 0 END) AS CHURN_12M
            FROM DVLP_FEATURES f
            LEFT JOIN CHURN_EVENTS ce
                ON ce.MBER_NO = f.MBER_NO
               AND ce.SPNSR_BSNS_ID = f.SPNSR_BSNS_ID
               AND ce.SPNSR_BSNS_NO = f.SPNSR_BSNS_NO
               AND ce.CHURN_MT > f.STDR_MT
               AND ce.CHURN_MT <= TO_CHAR(DATEADD(MONTH, 12, TO_DATE(f.STDR_MT || ''01'', ''YYYYMMDD'')), ''YYYYMM'')
            GROUP BY f.MBER_NO, f.SPNSR_BSNS_ID, f.SPNSR_BSNS_NO, f.STDR_MT
        )
        SELECT 
            f.STDR_MT,
            f.MBER_NO,
            f.SPNSR_BSNS_ID,
            f.SPNSR_BSNS_NO,
            f.CMPGN_CTGR_CD,
            f.STDR_MT_SPNSR_AMT,
            f.TENURE_MONTHS,
            f.CHN_CNT,
            f.INC_CNT,
            f.DEC_CNT, 
            f.RE_CNT,
            -- f.CANCL_CNT,
            f.INC_SPNSR_AMT,
            f.DEC_SPNSR_AMT,
            -- f.CANCL_SPNSR_AMT,
            COALESCE(p.PAY_RATE, 1) AS PAY_RATE,
            COALESCE(s.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(cf.CHURN_12M, 0) AS CHURN_12M
        FROM DVLP_FEATURES f
        LEFT JOIN PAY_FEATURES p 
            ON f.MBER_NO = p.MBER_NO 
           AND f.SPNSR_BSNS_ID = p.SPNSR_BSNS_ID
           AND f.SPNSR_BSNS_NO = p.SPNSR_BSNS_NO
           AND f.STDR_MT = p.STDR_MT
        LEFT JOIN SETLE_FEATURES s
            ON f.MBER_NO = s.MBER_NO
           AND f.STDR_MT = s.STDR_MT
        LEFT JOIN CHURN_FLAG cf
            ON f.MBER_NO = cf.MBER_NO
           AND f.SPNSR_BSNS_ID = cf.SPNSR_BSNS_ID
           AND f.SPNSR_BSNS_NO = cf.SPNSR_BSNS_NO
           AND f.STDR_MT = cf.STDR_MT
        ';

        -- =============================================================================
        -- STEP 2: 학습용 뷰 생성 + 모델 학습
        -- =============================================================================
        CREATE OR REPLACE VIEW GN_DW.ML.ML_TRAIN_DATA_SPNSR_CHURN_12M_V AS
        SELECT 
            CMPGN_CTGR_CD,
            STDR_MT_SPNSR_AMT,
            TENURE_MONTHS,
            CHN_CNT,
            INC_CNT,
            DEC_CNT,
            RE_CNT,
            -- CANCL_CNT,
            INC_SPNSR_AMT,
            DEC_SPNSR_AMT,
            -- CANCL_SPNSR_AMT,
            PAY_RATE,
            SETLE_CD,
            CHURN_12M
        FROM GN_DW.ML.ML_TRAIN_DATA_SPNSR_CHURN_12M;

        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.SPNSR_CHURN_CLASSIFIER_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'GN_DW.ML.ML_TRAIN_DATA_SPNSR_CHURN_12M_V'),
            TARGET_COLNAME => 'CHURN_12M',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 3: 예측 데이터 구성 (현재 활성 후원건)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_ACT_SPNSR_CHURN_12M AS
        WITH 
        CMPGN_CTGR AS (
            SELECT DISTINCT CMPGN_CTGR_CD
            FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
            WHERE CMPGN_CTGR_CD IS NOT NULL
        ),
        CURRENT_ACTIVE AS (
            SELECT
                d.STDR_MT,
                d.MBER_NO,
                d.SPNSR_BSNS_ID,
                d.SPNSR_BSNS_NO,
                d.CMPGN_CTGR_CD,
                d.STDR_MT_SPNSR_AMT,
                DATEDIFF(''MONTH'', TO_DATE(d.FIRST_OCCRRNC_DE, ''YYYYMMDD''), TO_DATE(d.STDR_MT || ''01'', ''YYYYMMDD'')) AS TENURE_MONTHS,
                d.CHN_CNT,
                d.INC_CNT,
                d.DEC_CNT,
                d.RE_CNT,
                -- d.CANCL_CNT,
                d.INC_SPNSR_AMT,
                d.DEC_SPNSR_AMT
                -- d.CANCL_SPNSR_AMT
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT d
            JOIN CMPGN_CTGR c ON d.CMPGN_CTGR_CD = c.CMPGN_CTGR_CD
            WHERE d.STDR_MT = ''' || :V_STDR_MT || '''
              AND d.STDR_MT_DVLP_DIV_CD NOT IN (''5'')
        ),
        PAY_FEATURES AS (
            SELECT 
                MBER_NO,
                SPNSR_BSNS_ID,
                DIV0NULL(SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE
            FROM GN_DW.ML.MBRFEE_PAY_DTLS
            WHERE LEFT(MBRFEE_MT, 6) = ''' || :V_STDR_MT || '''
            GROUP BY MBER_NO, SPNSR_BSNS_ID
        ),
        SETLE_FEATURES AS (
            SELECT MBER_NO, STDR_MT_SETLE_CD
            FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
            WHERE STDR_MT = ''' || :V_STDR_MT || '''
        )
        SELECT 
            a.STDR_MT,
            a.MBER_NO,
            a.SPNSR_BSNS_ID,
            a.SPNSR_BSNS_NO,
            a.CMPGN_CTGR_CD,
            a.STDR_MT_SPNSR_AMT,
            a.TENURE_MONTHS,
            a.CHN_CNT,
            a.INC_CNT,
            a.DEC_CNT,
            a.RE_CNT,
            -- a.CANCL_CNT,
            a.INC_SPNSR_AMT,
            a.DEC_SPNSR_AMT,
            -- a.CANCL_SPNSR_AMT,
            COALESCE(p.PAY_RATE, 1) AS PAY_RATE,
            COALESCE(s.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD
        FROM CURRENT_ACTIVE a
        LEFT JOIN PAY_FEATURES p 
            ON a.MBER_NO = p.MBER_NO AND a.SPNSR_BSNS_ID = p.SPNSR_BSNS_ID
        LEFT JOIN SETLE_FEATURES s
            ON a.MBER_NO = s.MBER_NO
        ';

        -- =============================================================================
        -- STEP 4: 예측 실행 (테이블 없으면 생성+COMMENT, 있으면 DELETE 후 INSERT)
        -- =============================================================================
        -- 테이블 존재 여부 확인 후 생성 또는 DELETE+INSERT
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M (
            STDR_MT VARCHAR COMMENT '기준월 (YYYYMM)',
            MBER_NO VARCHAR COMMENT '회원번호',
            SPNSR_BSNS_ID VARCHAR COMMENT '후원사업ID',
            SPNSR_BSNS_NO VARCHAR COMMENT '후원사업번호',
            CMPGN_CTGR_CD VARCHAR COMMENT '캠페인 카테고리 코드',
            PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
        )
        COMMENT = '후원건(SPNSR_BSNS_NO) 단위 향후 12개월 내 중단확률 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 결과 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT, 
            MBER_NO,
            SPNSR_BSNS_ID,
            SPNSR_BSNS_NO,
            CMPGN_CTGR_CD,
            GN_DW.ML.SPNSR_CHURN_CLASSIFIER_MODEL!PREDICT(
                INPUT_DATA => OBJECT_CONSTRUCT(
                    ''CMPGN_CTGR_CD'', CMPGN_CTGR_CD,
                    ''STDR_MT_SPNSR_AMT'', STDR_MT_SPNSR_AMT,
                    ''TENURE_MONTHS'', TENURE_MONTHS,
                    ''CHN_CNT'', CHN_CNT,
                    ''INC_CNT'', INC_CNT,
                    ''DEC_CNT'', DEC_CNT,
                    ''RE_CNT'', RE_CNT,
                    -- ''CANCL_CNT'', CANCL_CNT,
                    ''INC_SPNSR_AMT'', INC_SPNSR_AMT,
                    ''DEC_SPNSR_AMT'', DEC_SPNSR_AMT,
                    -- ''CANCL_SPNSR_AMT'', CANCL_SPNSR_AMT,
                    ''PAY_RATE'', PAY_RATE,
                    ''SETLE_CD'', SETLE_CD
                )
            ) AS PREDICTION
        FROM GN_DW.ML.ML_TRAIN_DATA_ACT_SPNSR_CHURN_12M
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
