-- =============================================================================
-- 프로시져: 장기회원(충성회원) 성장 가능성 예측
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 장기회원(후원 10년이상 유지)만드는 핵심 요인 도출. 장기회원 성장 가능성 높은 회원 예측 : 회원실9
-- GN_DW.ML.SP_LOYAL_MBER_PREDICT
-- 회원 충성도 예측
-- 기준월을 입력받아 회원의 초기 후원 및 납입 데이터를 기반으로 회원 단위 장기회원(충성회원) 전환 가능성을 예측하는 머신러닝 모델을 학습하고 예측 결과를 산출한다.
-- 회원별 가입 후 경과기간을 기준으로 장기회원 여부를 정의하며, 가입 후 경과기간이 120개월 이상인 회원은 장기회원(IS_LOYAL = 1), 그 외는 비장기회원(IS_LOYAL = 0)으로 구분한다. 단, 학습 대상에는 경과기간이 120개월 이상이거나 최종 회원 상태가 중단인 회원을 포함한다.
-- 가입 후 초기 24개월의 활성 후원월 수, 후원건 수, 총·평균 후원금액, 증액·감액·해지·재후원 건수 및 금액, 중단율, 후원금액 표준편차, 납입 성공률, 납입 요청 건수 및 납입금액, 결제수단, 법인/개인 구분 등의 데이터를 활용하여 학습데이터를 구성한다.
-- 구성된 초기 24개월 특성 데이터를 기반으로 장기회원 여부를 학습하고, Snowflake Classification 모델을 생성한다.
-- 입력 기준월에 활동 중이며 가입 후 경과기간이 24개월 이상 120개월 미만인 회원을 대상으로 초기 24개월의 동일한 특성 데이터를 구성하고, 학습된 모델을 이용하여 장기회원으로 성장할 가능성 및 예측 결과를 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_LOYAL_MBER 테이블에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_LOYAL_MBER_PREDICT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_LOYAL_MBER_PREDICT';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 장기회원 vs 비장기회원 정의
        -- =============================================================================
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_LOYAL_MBER AS
        SELECT 
            MBER_NO,
            MIN(STDR_MT) AS FIRST_MT,
            MAX(STDR_MT) AS LAST_MT,
            COUNT(DISTINCT STDR_MT) AS ACTIVE_MONTHS,
            MAX_BY(STDR_MT_MBER_STAT_CD, STDR_MT) AS LAST_STAT_CD,
            MAX(MONTHS_SINCE_JOIN) AS MAX_TENURE,
            CASE 
                WHEN MAX(MONTHS_SINCE_JOIN) >= 120 THEN 1
                ELSE 0
            END AS IS_LOYAL
        FROM GN_DW.ML.MBER_MONTHLY_INFO
        GROUP BY MBER_NO
        HAVING MAX(MONTHS_SINCE_JOIN) >= 120
           OR MAX_BY(STDR_MT_MBER_STAT_CD, STDR_MT) = '12';

        -- =============================================================================
        -- STEP 2: 학습 데이터셋 구성 (가입 후 24개월 시점 피처)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_LOYAL_MBER_M24 AS
        WITH 
        EARLY_DVLP AS (
            SELECT 
                d.MBER_NO,
                COUNT(DISTINCT d.STDR_MT) AS ACTIVE_MONTHS_24,
                COUNT(DISTINCT d.SPNSR_BSNS_ID) AS SPNSR_CNT_24,
                SUM(d.STDR_MT_SPNSR_AMT) AS TOTAL_AMT_24,
                AVG(d.STDR_MT_SPNSR_AMT) AS AVG_AMT_24,
                SUM(d.INC_CNT) AS INC_CNT_24,
                SUM(d.DEC_CNT) AS DEC_CNT_24,
                SUM(d.CANCL_CNT) AS CANCL_CNT_24,
                SUM(d.RE_CNT) AS RE_CNT_24,
                SUM(d.INC_SPNSR_AMT) AS INC_AMT_24,
                SUM(d.DEC_SPNSR_AMT) AS DEC_AMT_24,
                SUM(d.CANCL_SPNSR_AMT) AS CANCL_AMT_24,
                DIV0NULL(ABS(SUM(d.CANCL_SPNSR_AMT)), NULLIF(SUM(d.STDR_MT_SPNSR_AMT), 0)) AS DNST_RT_24,
                STDDEV(d.STDR_MT_SPNSR_AMT) AS AMT_STDDEV_24
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT d
            JOIN GN_DW.ML.MBER_MONTHLY_INFO m 
                ON d.MBER_NO = m.MBER_NO AND d.STDR_MT = m.STDR_MT
            WHERE m.MONTHS_SINCE_JOIN <= 24
            GROUP BY d.MBER_NO
        ),
        EARLY_PAY AS (
            SELECT 
                p.MBER_NO,
                COUNT(*) AS PAY_REQ_CNT_24,
                SUM(CASE WHEN p.PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END) AS PAY_SUC_CNT_24,
                DIV0NULL(SUM(CASE WHEN p.PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE_24,
                SUM(p.RGR_PAY_AMT) AS TOTAL_PAY_AMT_24
            FROM GN_DW.ML.MBRFEE_PAY_DTLS p
            JOIN GN_DW.ML.MBER_MONTHLY_INFO m
                ON p.MBER_NO = m.MBER_NO AND LEFT(p.MBRFEE_MT, 6) = m.STDR_MT
            WHERE m.MONTHS_SINCE_JOIN <= 24
            GROUP BY p.MBER_NO
        ),
        EARLY_SETLE AS (
            SELECT MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD
            FROM (
                SELECT 
                    MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD,
                    ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY STDR_MT) AS RN
                FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
            )
            WHERE RN = 1
        )
        SELECT 
            l.MBER_NO,
            COALESCE(d.ACTIVE_MONTHS_24, 0) AS ACTIVE_MONTHS_24,
            COALESCE(d.SPNSR_CNT_24, 0) AS SPNSR_CNT_24,
            COALESCE(d.TOTAL_AMT_24, 0) AS TOTAL_AMT_24,
            COALESCE(d.AVG_AMT_24, 0) AS AVG_AMT_24,
            COALESCE(d.INC_CNT_24, 0) AS INC_CNT_24,
            COALESCE(d.DEC_CNT_24, 0) AS DEC_CNT_24,
            COALESCE(d.CANCL_CNT_24, 0) AS CANCL_CNT_24,
            COALESCE(d.RE_CNT_24, 0) AS RE_CNT_24,
            COALESCE(d.INC_AMT_24, 0) AS INC_AMT_24,
            COALESCE(d.DEC_AMT_24, 0) AS DEC_AMT_24,
            COALESCE(d.CANCL_AMT_24, 0) AS CANCL_AMT_24,
            COALESCE(d.DNST_RT_24, 0) AS DNST_RT_24,
            COALESCE(d.AMT_STDDEV_24, 0) AS AMT_STDDEV_24,
            COALESCE(p.PAY_RATE_24, 1) AS PAY_RATE_24,
            COALESCE(p.PAY_REQ_CNT_24, 0) AS PAY_REQ_CNT_24,
            COALESCE(p.TOTAL_PAY_AMT_24, 0) AS TOTAL_PAY_AMT_24,
            COALESCE(se.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(se.CPR_DIV_CD, ''UNKNOWN'') AS CPR_DIV_CD,
            l.IS_LOYAL
        FROM GN_DW.ML.ML_TRAIN_DATA_LOYAL_MBER l
        LEFT JOIN EARLY_DVLP d ON l.MBER_NO = d.MBER_NO
        LEFT JOIN EARLY_PAY p ON l.MBER_NO = p.MBER_NO
        LEFT JOIN EARLY_SETLE se ON l.MBER_NO = se.MBER_NO
        ';

        -- =============================================================================
        -- STEP 3: CLASSIFICATION 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.LOYAL_MBER_CLASSIFIER_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'GN_DW.ML.ML_TRAIN_DATA_LOYAL_MBER_M24'),
            TARGET_COLNAME => 'IS_LOYAL',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 4: 예측 데이터 구성 (24개월~120개월 미만 활동 회원)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_NON_LOYAL_MBER AS
        WITH 
        CURRENT_MBER AS (
            SELECT MBER_NO, MAX(MONTHS_SINCE_JOIN) AS CURRENT_TENURE
            FROM GN_DW.ML.MBER_MONTHLY_INFO
            WHERE STDR_MT = ''' || :V_STDR_MT || '''
              AND STDR_MT_MBER_STAT_CD != ''12''
            GROUP BY MBER_NO
            HAVING MAX(MONTHS_SINCE_JOIN) BETWEEN 24 AND 119
        ),
        EARLY_DVLP AS (
            SELECT 
                d.MBER_NO,
                COUNT(DISTINCT d.STDR_MT) AS ACTIVE_MONTHS_24,
                COUNT(DISTINCT d.SPNSR_BSNS_ID) AS SPNSR_CNT_24,
                SUM(d.STDR_MT_SPNSR_AMT) AS TOTAL_AMT_24,
                AVG(d.STDR_MT_SPNSR_AMT) AS AVG_AMT_24,
                SUM(d.INC_CNT) AS INC_CNT_24,
                SUM(d.DEC_CNT) AS DEC_CNT_24,
                SUM(d.CANCL_CNT) AS CANCL_CNT_24,
                SUM(d.RE_CNT) AS RE_CNT_24,
                SUM(d.INC_SPNSR_AMT) AS INC_AMT_24,
                SUM(d.DEC_SPNSR_AMT) AS DEC_AMT_24,
                SUM(d.CANCL_SPNSR_AMT) AS CANCL_AMT_24,
                DIV0NULL(ABS(SUM(d.CANCL_SPNSR_AMT)), NULLIF(SUM(d.STDR_MT_SPNSR_AMT), 0)) AS DNST_RT_24,
                STDDEV(d.STDR_MT_SPNSR_AMT) AS AMT_STDDEV_24
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT d
            JOIN GN_DW.ML.MBER_MONTHLY_INFO m 
                ON d.MBER_NO = m.MBER_NO AND d.STDR_MT = m.STDR_MT
            WHERE m.MONTHS_SINCE_JOIN <= 24
              AND d.MBER_NO IN (SELECT MBER_NO FROM CURRENT_MBER)
            GROUP BY d.MBER_NO
        ),
        EARLY_PAY AS (
            SELECT 
                p.MBER_NO,
                COUNT(*) AS PAY_REQ_CNT_24,
                DIV0NULL(SUM(CASE WHEN p.PAY_SUC_STATUS = ''Y'' THEN 1 ELSE 0 END), COUNT(*)) AS PAY_RATE_24,
                SUM(p.RGR_PAY_AMT) AS TOTAL_PAY_AMT_24
            FROM GN_DW.ML.MBRFEE_PAY_DTLS p
            JOIN GN_DW.ML.MBER_MONTHLY_INFO m
                ON p.MBER_NO = m.MBER_NO AND LEFT(p.MBRFEE_MT, 6) = m.STDR_MT
            WHERE m.MONTHS_SINCE_JOIN <= 24
              AND p.MBER_NO IN (SELECT MBER_NO FROM CURRENT_MBER)
            GROUP BY p.MBER_NO
        ),
        EARLY_SETLE AS (
            SELECT MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD
            FROM (
                SELECT 
                    MBER_NO, STDR_MT_SETLE_CD, CPR_DIV_CD,
                    ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY STDR_MT) AS RN
                FROM GN_DW.ML.MBER_MONTHLY_SETLE_INFO
                WHERE MBER_NO IN (SELECT MBER_NO FROM CURRENT_MBER)
            )
            WHERE RN = 1
        )
        SELECT 
            cm.MBER_NO, cm.CURRENT_TENURE,
            COALESCE(d.ACTIVE_MONTHS_24, 0) AS ACTIVE_MONTHS_24,
            COALESCE(d.SPNSR_CNT_24, 0) AS SPNSR_CNT_24,
            COALESCE(d.TOTAL_AMT_24, 0) AS TOTAL_AMT_24,
            COALESCE(d.AVG_AMT_24, 0) AS AVG_AMT_24,
            COALESCE(d.INC_CNT_24, 0) AS INC_CNT_24,
            COALESCE(d.DEC_CNT_24, 0) AS DEC_CNT_24,
            COALESCE(d.CANCL_CNT_24, 0) AS CANCL_CNT_24,
            COALESCE(d.RE_CNT_24, 0) AS RE_CNT_24,
            COALESCE(d.INC_AMT_24, 0) AS INC_AMT_24,
            COALESCE(d.DEC_AMT_24, 0) AS DEC_AMT_24,
            COALESCE(d.CANCL_AMT_24, 0) AS CANCL_AMT_24,
            COALESCE(d.DNST_RT_24, 0) AS DNST_RT_24,
            COALESCE(d.AMT_STDDEV_24, 0) AS AMT_STDDEV_24,
            COALESCE(p.PAY_RATE_24, 1) AS PAY_RATE_24,
            COALESCE(p.PAY_REQ_CNT_24, 0) AS PAY_REQ_CNT_24,
            COALESCE(p.TOTAL_PAY_AMT_24, 0) AS TOTAL_PAY_AMT_24,
            COALESCE(se.STDR_MT_SETLE_CD, ''UNKNOWN'') AS SETLE_CD,
            COALESCE(se.CPR_DIV_CD, ''UNKNOWN'') AS CPR_DIV_CD
        FROM CURRENT_MBER cm
        LEFT JOIN EARLY_DVLP d ON cm.MBER_NO = d.MBER_NO
        LEFT JOIN EARLY_PAY p ON cm.MBER_NO = p.MBER_NO
        LEFT JOIN EARLY_SETLE se ON cm.MBER_NO = se.MBER_NO
        ';

        -- =============================================================================
        -- STEP 5: 예측 실행 (테이블 없으면 생성+COMMENT, 있으면 DELETE 후 INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_LOYAL_MBER (
            STDR_MT VARCHAR COMMENT '기준월 (YYYYMM)',
            MBER_NO VARCHAR COMMENT '회원번호',
            PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
        )
        COMMENT = '회원(MBER_NO) 단위 충성회원 성장 가능성 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_LOYAL_MBER WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 결과 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_LOYAL_MBER
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            MBER_NO, 
            -- CURRENT_TENURE,
            -- ACTIVE_MONTHS_24, SPNSR_CNT_24, TOTAL_AMT_24, AVG_AMT_24,
            -- INC_CNT_24, DEC_CNT_24, CANCL_CNT_24, RE_CNT_24,
            -- INC_AMT_24, DEC_AMT_24, CANCL_AMT_24, DNST_RT_24, AMT_STDDEV_24,
            -- PAY_RATE_24, PAY_REQ_CNT_24, TOTAL_PAY_AMT_24,
            -- SETLE_CD, CPR_DIV_CD,
            GN_DW.ML.LOYAL_MBER_CLASSIFIER_MODEL!PREDICT(
                INPUT_DATA => OBJECT_CONSTRUCT(
                    ''ACTIVE_MONTHS_24'', ACTIVE_MONTHS_24,
                    ''SPNSR_CNT_24'', SPNSR_CNT_24,
                    ''TOTAL_AMT_24'', TOTAL_AMT_24,
                    ''AVG_AMT_24'', AVG_AMT_24,
                    ''INC_CNT_24'', INC_CNT_24,
                    ''DEC_CNT_24'', DEC_CNT_24,
                    ''CANCL_CNT_24'', CANCL_CNT_24,
                    ''RE_CNT_24'', RE_CNT_24,
                    ''INC_AMT_24'', INC_AMT_24,
                    ''DEC_AMT_24'', DEC_AMT_24,
                    ''CANCL_AMT_24'', CANCL_AMT_24,
                    ''DNST_RT_24'', DNST_RT_24,
                    ''AMT_STDDEV_24'', AMT_STDDEV_24,
                    ''PAY_RATE_24'', PAY_RATE_24,
                    ''PAY_REQ_CNT_24'', PAY_REQ_CNT_24,
                    ''TOTAL_PAY_AMT_24'', TOTAL_PAY_AMT_24,
                    ''SETLE_CD'', SETLE_CD,
                    ''CPR_DIV_CD'', CPR_DIV_CD
                )
            ) AS PREDICTION
        FROM GN_DW.ML.ML_TRAIN_DATA_NON_LOYAL_MBER
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
