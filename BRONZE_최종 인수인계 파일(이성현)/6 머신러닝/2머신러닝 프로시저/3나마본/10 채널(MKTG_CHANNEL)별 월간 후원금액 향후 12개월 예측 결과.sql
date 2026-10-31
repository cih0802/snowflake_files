-- =============================================================================
-- 프로시져: 채널 단위 회원평균 LTV 예측
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 가장 높은 LTV 창출하는 채널 예상 : 나마본17
-- GN_DW.ML.SP_MKTG_CHANNEL_MBER_AVG_LTV_FORECAST
-- 마케팅 채널별 회원평균 후원금액 예측
-- 기준월을 입력받아 마케팅 채널별 과거 월간 회원평균 후원금액을 기반으로 향후 12개월의 채널별 회원평균 후원금액을 예측하는 시계열 모델을 학습하고 예측 결과를 산출한다.
-- 기준월에 실적이 존재하면서 최소 24개월 이상의 월별 데이터가 있는 캠페인을 대상으로 데이터를 선정하고, 2024년 1월부터 입력 기준월까지의 데이터를 활용하여 학습데이터를 구성한다.
-- 캠페인별 월간 후원금액을 회원 수로 나누어 캠페인 채널(MKTG_CHANNEL)별 월간 회원평균 후원금액을 산출한다.
-- 캠페인 채널을 시계열 구분 기준으로 설정하여 Snowflake Forecast 모델을 학습한다.
-- 학습된 모델을 이용하여 향후 12개월의 채널별 회원평균 후원금액과 95% 신뢰구간의 하한·상한을 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV 테이블에 기준월별·채널별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 별도의 LTV 산출 로직은 현재 주석 처리되어 있어 현 프로시저에서는 회원평균 후원금액 예측 결과만 산출·저장한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_MKTG_CHANNEL_MBER_AVG_LTV_FORECAST(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_MKTG_CHANNEL_MBER_AVG_LTV_FORECAST';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터 구성 (채널별 월별 회원평균 후원금액 시계열)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MONTHLY_MKTG_CHANNEL_AVG_AMT AS
        SELECT 
            MKTG_CHANNEL, 
            STDR_DE, 
            ROUND(SUM(STDR_MT_SPNSR_AMT) / COUNT(DISTINCT MBER_NO)) AS AVG_MBER_AMT
        FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
        WHERE CMPGN_CD IN (
            SELECT CMPGN_CD 
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT 
            WHERE CMPGN_CD IN (
                SELECT CMPGN_CD 
                FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT 
                WHERE STDR_MT = ''' || :V_STDR_MT || '''
            )
            GROUP BY CMPGN_CD 
            HAVING COUNT(DISTINCT STDR_MT) >= 24
        )
        AND STDR_MT BETWEEN ''202401'' AND ''' || :V_STDR_MT || '''
        GROUP BY MKTG_CHANNEL, STDR_DE
        ORDER BY MKTG_CHANNEL, STDR_DE
        ';

        -- =============================================================================
        -- STEP 2: FORECAST 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.FORECAST GN_DW.ML.MKTG_CHANNEL_LTV_FORECAST_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'GN_DW.ML.ML_TRAIN_DATA_MONTHLY_MKTG_CHANNEL_AVG_AMT'),
            SERIES_COLNAME => 'MKTG_CHANNEL',
            TIMESTAMP_COLNAME => 'STDR_DE',
            TARGET_COLNAME => 'AVG_MBER_AMT'
        );

        -- =============================================================================
        -- STEP 3: 결과 테이블1 (ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV) - 없으면 생성, 있으면 DELETE+INSERT
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV (
            STDR_MT VARCHAR COMMENT '예측 실행 기준월 (YYYYMM)',
            MKTG_CHANNEL VARCHAR COMMENT '캠페인 채널 코드 (MKTG_CHANNEL)',
            TS TIMESTAMP_NTZ COMMENT '예측 기준일 (월 시작일)',
            FORECAST FLOAT COMMENT '예측 회원평균 후원금액',
            LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
            UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
        )
        COMMENT = '캠페인 채널 코드 (MKTG_CHANNEL)별 회원평균 후원금액 향후 12개월 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 실행 및 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            SERIES AS MKTG_CHANNEL,
            TS,
            FORECAST,
            LOWER_BOUND,
            UPPER_BOUND
        FROM TABLE(GN_DW.ML.MKTG_CHANNEL_LTV_FORECAST_MODEL!FORECAST(
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


