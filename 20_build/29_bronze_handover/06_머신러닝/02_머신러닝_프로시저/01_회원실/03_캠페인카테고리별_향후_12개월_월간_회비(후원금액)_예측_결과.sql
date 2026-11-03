-- =============================================================================
-- 프로시져: 캠페인카테고리별 향후 12개월 회비 예측 (FORECAST)
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- GN_DW.ML.SP_CMPGN_CTGR_AMT_FORECAST
-- 캠페인 카테고리별 후원금액 예측
-- 기준월을 입력받아 캠페인 카테고리별 과거 월간 후원금액 데이터를 기반으로 향후 12개월의 월별 후원금액을 예측하는 시계열 모델을 학습하고 예측 결과를 산출한다.
-- 2018년 1월부터 기준월까지의 월별 후원금액을 캠페인 카테고리별로 집계하여 학습데이터를 구성한다.
-- 캠페인 카테고리를 시계열 구분 기준으로 설정하고, 월별 후원금액을 예측 대상으로 하여 Snowflake Forecast 모델을 학습한다.
-- 학습된 모델을 이용하여 캠페인 카테고리별 향후 12개월 월간 후원금액 및 95% 신뢰구간을 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT 테이블에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_CMPGN_CTGR_AMT_FORECAST(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_CMPGN_CTGR_AMT_FORECAST';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터셋 구성 (캠페인카테고리별 월간 회비 시계열)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_CMPGN_CTGR_MONTHLY_AMT AS
        SELECT 
            TO_DATE(d.STDR_MT || ''01'', ''YYYYMMDD'') AS STDR_DE,
            c.CMPGN_CTGR_CD,
            SUM(d.STDR_MT_SPNSR_AMT) AS MONTHLY_SPNSR_AMT
        FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT d
        JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG c ON d.CMPGN_CD = c.CMPGN_CD
        WHERE c.CMPGN_CTGR_CD IS NOT NULL
          AND d.STDR_MT >= ''201801''
          AND d.STDR_MT <= ''' || :V_STDR_MT || '''
        GROUP BY d.STDR_MT, c.CMPGN_CTGR_CD
        ORDER BY c.CMPGN_CTGR_CD, STDR_DE
        ';

        -- =============================================================================
        -- STEP 2: FORECAST 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.FORECAST GN_DW.ML.CMPGN_CTGR_AMT_FORECAST_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'GN_DW.ML.ML_TRAIN_DATA_CMPGN_CTGR_MONTHLY_AMT'),
            SERIES_COLNAME => 'CMPGN_CTGR_CD',
            TIMESTAMP_COLNAME => 'STDR_DE',
            TARGET_COLNAME => 'MONTHLY_SPNSR_AMT',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 3: 결과 테이블 생성 (없으면 CREATE, 있으면 DELETE+INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT (
            STDR_MT VARCHAR COMMENT '예측 실행 기준월 (YYYYMM)',
            CMPGN_CTGR_CD VARCHAR COMMENT '캠페인 카테고리 코드 (CMPGN_CTGR_CD)',
            TS TIMESTAMP_NTZ COMMENT '예측 기준일 (월 시작일)',
            FORECAST FLOAT COMMENT '예측 회비금액',
            LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
            UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
        )
        COMMENT = '캠페인카테고리별 향후 12개월 월간 회비(후원금액) 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 실행 및 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            SERIES AS CMPGN_CTGR_CD,
            TS,
            FORECAST,
            LOWER_BOUND,
            UPPER_BOUND
        FROM TABLE(GN_DW.ML.CMPGN_CTGR_AMT_FORECAST_MODEL!FORECAST(
            FORECASTING_PERIODS => 12
        ))
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
