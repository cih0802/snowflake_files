-- =============================================================================
-- 프로시져: 회원 단위 향후 12개월 내 증액 가능성 예측
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 활동회원중 향후 12개월 내 증액 가능성이 높은 회원 예측. : 회원실8
-- GN_DW.ML.SP_MBER_INC_12M_PREDICT측
-- 회원 12개월 증액 가능성 예측
-- 기준월을 입력받아 과거 회원 및 후원 데이터를 기반으로 회원 단위 향후 12개월 내 증액 여부를 예측하는 머신러닝 모델을 학습하고 예측 결과를 산출한다.
-- 회원별 활성 후원건 수, 총 후원금액, 신규·증액·감액·재후원·해지 건수 및 금액, 중단율, 납입 성공률, 납입금액, 가입 후 경과기간, 결제수단, 법인/개인 구분 등의 데이터를 활용하여 학습데이터를 구성한다.
-- 기준월 이후 12개월 이내 증액 이력이 발생한 경우를 INC_12M으로 정의하여 증액 여부를 학습하고, Snowflake Classification 모델을 생성한다.
-- 학습 데이터는 회원 상태가 중단되지 않은 회원을 대상으로 2022년 1월부터 기준월 12개월 전까지 기준 데이터를 활용하여 구성한다.
-- 입력 기준월의 현재 활동 회원을 대상으로 동일한 특성 데이터를 구성하고, 학습된 모델을 이용하여 향후 12개월 내 증액 가능성 및 예측 결과를 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_MBER_INC_12M 테이블에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_MBER_INC_12M_PREDICT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_TRAIN_END VARCHAR := TO_CHAR(DATEADD(MONTH, -12, TO_DATE(:V_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMM');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_MBER_INC_12M_PREDICT';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터셋 구성 (회원 단위, 증액 타겟)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MBER_INC_12M AS
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
        ),
        PAY_FEATURES AS (
            SELECT 
                LEFT(MBRFEE_MT, 6) AS STDR_MT, MBER_NO,
                COUNT(*) AS PAY_REQ_CNT,
                DIV0NULL(SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE,
                SUM(RGR_PAY_AMT) AS TOTAL_PAY_AMT
            FROM GN_DW.ML.MBRFEE_PAY_DTLS
            GROUP BY LEFT(MBRFEE_MT, 6), MBER_NO
        ),
        SETLE_FEATURES AS (
            SELECT STDR_MT, MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD
            FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
        ),
        INC_EVENTS AS (
            SELECT DISTINCT MBER_NO, STDR_MT AS INC_MT
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
            WHERE INC_CNT > 0
        )
        SELECT 
            m.STDR_MT, m.MBER_NO,
            s.STDR_MT_MBER_STAT_CD AS MBER_STAT_CD,
            s.MONTHS_SINCE_JOIN,
            COALESCE(d.ACTIVE_SPNSR_CNT, 0) AS ACTIVE_SPNSR_CNT,
            COALESCE(d.TOTAL_SPNSR_AMT, 0) AS TOTAL_SPNSR_AMT,
            COALESCE(d.TOTAL_NEW_CNT, 0) AS TOTAL_NEW_CNT,
            COALESCE(d.TOTAL_INC_CNT, 0) AS TOTAL_INC_CNT,
            COALESCE(d.TOTAL_DEC_CNT, 0) AS TOTAL_DEC_CNT,
            COALESCE(d.TOTAL_RE_CNT, 0) AS TOTAL_RE_CNT,
            COALESCE(d.TOTAL_CANCL_CNT, 0) AS TOTAL_CANCL_CNT,
            COALESCE(d.TOTAL_INC_AMT, 0) AS TOTAL_INC_AMT,
            COALESCE(d.TOTAL_DEC_AMT, 0) AS TOTAL_DEC_AMT,
            COALESCE(d.TOTAL_CANCL_AMT, 0) AS TOTAL_CANCL_AMT,
            COALESCE(d.DNST_RT, 0) AS DNST_RT,
            COALESCE(p.PAY_RATE, 1) AS PAY_RATE,
            COALESCE(p.PAY_REQ_CNT, 0) AS PAY_REQ_CNT,
            COALESCE(p.TOTAL_PAY_AMT, 0) AS TOTAL_PAY_AMT,
            COALESCE(se.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(se.CPR_DIV_CD, ''UNKNOWN'') AS CPR_DIV_CD,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM INC_EVENTS ie 
                    WHERE ie.MBER_NO = m.MBER_NO 
                      AND ie.INC_MT > m.STDR_MT 
                      AND ie.INC_MT <= TO_CHAR(DATEADD(MONTH, 12, TO_DATE(m.STDR_MT || ''01'', ''YYYYMMDD'')), ''YYYYMM'')
                ) THEN 1
                ELSE 0
            END AS INC_12M
        FROM (
            SELECT DISTINCT STDR_MT, MBER_NO
            FROM GN_DW.ML.MBER_MONTHLY_INFO
            WHERE STDR_MT_MBER_STAT_CD != ''12''
              AND STDR_MT BETWEEN ''202201'' AND ''' || :V_TRAIN_END || '''
        ) m
        LEFT JOIN MBER_STAT s ON m.MBER_NO = s.MBER_NO AND m.STDR_MT = s.STDR_MT
        LEFT JOIN MBER_DVLP d ON m.MBER_NO = d.MBER_NO AND m.STDR_MT = d.STDR_MT
        LEFT JOIN PAY_FEATURES p ON m.MBER_NO = p.MBER_NO AND m.STDR_MT = p.STDR_MT
        LEFT JOIN SETLE_FEATURES se ON m.MBER_NO = se.MBER_NO AND m.STDR_MT = se.STDR_MT
        ';

        -- =============================================================================
        -- STEP 2: 학습용 뷰 + 모델 학습
        -- =============================================================================
        CREATE OR REPLACE VIEW GN_DW.ML.ML_TRAIN_DATA_MBER_INC_12M_V AS
        SELECT
            MBER_STAT_CD, MONTHS_SINCE_JOIN, ACTIVE_SPNSR_CNT, TOTAL_SPNSR_AMT,
            TOTAL_NEW_CNT, TOTAL_INC_CNT, TOTAL_DEC_CNT, TOTAL_RE_CNT, TOTAL_CANCL_CNT,
            TOTAL_INC_AMT, TOTAL_DEC_AMT, TOTAL_CANCL_AMT, DNST_RT,
            PAY_RATE, PAY_REQ_CNT, TOTAL_PAY_AMT, SETLE_CD, CPR_DIV_CD, INC_12M
        FROM GN_DW.ML.ML_TRAIN_DATA_MBER_INC_12M;

        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.MBER_INC_12M_CLASSIFIER_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'GN_DW.ML.ML_TRAIN_DATA_MBER_INC_12M_V'),
            TARGET_COLNAME => 'INC_12M',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 3: 예측 데이터 구성 (현재 활동 회원)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MBER_INC_STDR_MT AS
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
            WHERE STDR_MT = ''' || :V_STDR_MT || '''
            GROUP BY STDR_MT, MBER_NO
        ),
        PAY_FEATURES AS (
            SELECT 
                MBER_NO,
                COUNT(*) AS PAY_REQ_CNT,
                DIV0NULL(SUM(CASE WHEN PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE,
                SUM(RGR_PAY_AMT) AS TOTAL_PAY_AMT
            FROM GN_DW.ML.MBRFEE_PAY_DTLS
            WHERE LEFT(MBRFEE_MT, 6) = ''' || :V_STDR_MT || '''
            GROUP BY MBER_NO
        ),
        SETLE_FEATURES AS (
            SELECT MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD
            FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
            WHERE STDR_MT = ''' || :V_STDR_MT || '''
        )
        SELECT 
            m.STDR_MT, m.MBER_NO,
            m.STDR_MT_MBER_STAT_CD AS MBER_STAT_CD,
            m.MONTHS_SINCE_JOIN,
            COALESCE(d.ACTIVE_SPNSR_CNT, 0) AS ACTIVE_SPNSR_CNT,
            COALESCE(d.TOTAL_SPNSR_AMT, 0) AS TOTAL_SPNSR_AMT,
            COALESCE(d.TOTAL_NEW_CNT, 0) AS TOTAL_NEW_CNT,
            COALESCE(d.TOTAL_INC_CNT, 0) AS TOTAL_INC_CNT,
            COALESCE(d.TOTAL_DEC_CNT, 0) AS TOTAL_DEC_CNT,
            COALESCE(d.TOTAL_RE_CNT, 0) AS TOTAL_RE_CNT,
            COALESCE(d.TOTAL_CANCL_CNT, 0) AS TOTAL_CANCL_CNT,
            COALESCE(d.TOTAL_INC_AMT, 0) AS TOTAL_INC_AMT,
            COALESCE(d.TOTAL_DEC_AMT, 0) AS TOTAL_DEC_AMT,
            COALESCE(d.TOTAL_CANCL_AMT, 0) AS TOTAL_CANCL_AMT,
            COALESCE(d.DNST_RT, 0) AS DNST_RT,
            COALESCE(p.PAY_RATE, 1) AS PAY_RATE,
            COALESCE(p.PAY_REQ_CNT, 0) AS PAY_REQ_CNT,
            COALESCE(p.TOTAL_PAY_AMT, 0) AS TOTAL_PAY_AMT,
            COALESCE(se.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(se.CPR_DIV_CD, ''UNKNOWN'') AS CPR_DIV_CD
        FROM GN_DW.ML.MBER_MONTHLY_INFO m
        LEFT JOIN MBER_DVLP d ON m.MBER_NO = d.MBER_NO
        LEFT JOIN PAY_FEATURES p ON m.MBER_NO = p.MBER_NO
        LEFT JOIN SETLE_FEATURES se ON m.MBER_NO = se.MBER_NO
        WHERE m.STDR_MT = ''' || :V_STDR_MT || '''
          AND m.STDR_MT_MBER_STAT_CD != ''12''
        ';

        -- =============================================================================
        -- STEP 4: 예측 실행 (테이블 없으면 생성+COMMENT, 있으면 DELETE 후 INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_MBER_INC_12M (
            STDR_MT VARCHAR COMMENT '기준월 (YYYYMM)',
            MBER_NO VARCHAR COMMENT '회원번호',
            PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
        )
        COMMENT = '회원(MBER_NO) 단위 향후 12개월 내 증액 가능성 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_MBER_INC_12M WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 결과 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_MBER_INC_12M
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            MBER_NO, 
            -- MBER_STAT_CD, MONTHS_SINCE_JOIN,
            -- ACTIVE_SPNSR_CNT, TOTAL_SPNSR_AMT, TOTAL_NEW_CNT,
            -- TOTAL_INC_CNT, TOTAL_DEC_CNT, TOTAL_RE_CNT, TOTAL_CANCL_CNT,
            -- TOTAL_INC_AMT, TOTAL_DEC_AMT, TOTAL_CANCL_AMT,
            -- DNST_RT, PAY_RATE, PAY_REQ_CNT, TOTAL_PAY_AMT,
            -- SETLE_CD, CPR_DIV_CD,
            GN_DW.ML.MBER_INC_12M_CLASSIFIER_MODEL!PREDICT(
                INPUT_DATA => OBJECT_CONSTRUCT(
                    ''MBER_STAT_CD'', MBER_STAT_CD,
                    ''MONTHS_SINCE_JOIN'', MONTHS_SINCE_JOIN,
                    ''ACTIVE_SPNSR_CNT'', ACTIVE_SPNSR_CNT,
                    ''TOTAL_SPNSR_AMT'', TOTAL_SPNSR_AMT,
                    ''TOTAL_NEW_CNT'', TOTAL_NEW_CNT,
                    ''TOTAL_INC_CNT'', TOTAL_INC_CNT,
                    ''TOTAL_DEC_CNT'', TOTAL_DEC_CNT,
                    ''TOTAL_RE_CNT'', TOTAL_RE_CNT,
                    ''TOTAL_CANCL_CNT'', TOTAL_CANCL_CNT,
                    ''TOTAL_INC_AMT'', TOTAL_INC_AMT,
                    ''TOTAL_DEC_AMT'', TOTAL_DEC_AMT,
                    ''TOTAL_CANCL_AMT'', TOTAL_CANCL_AMT,
                    ''DNST_RT'', DNST_RT,
                    ''PAY_RATE'', PAY_RATE,
                    ''PAY_REQ_CNT'', PAY_REQ_CNT,
                    ''TOTAL_PAY_AMT'', TOTAL_PAY_AMT,
                    ''SETLE_CD'', SETLE_CD,
                    ''CPR_DIV_CD'', CPR_DIV_CD
                )
            ) AS PREDICTION
        FROM GN_DW.ML.ML_TRAIN_DATA_MBER_INC_STDR_MT
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
