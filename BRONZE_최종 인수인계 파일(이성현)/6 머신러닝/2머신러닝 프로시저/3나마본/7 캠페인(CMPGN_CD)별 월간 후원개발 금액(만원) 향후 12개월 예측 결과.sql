-- =============================================================================
-- 프로시져: 캠페인별 월간 후원개발 금액 예측 (FORECAST)
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 특정캠페인 캠페인별(후원금액기준 상위 100개) 월간 후원개발 금액 예측 : 나마본3
-- GN_DW.ML.SP_MONTHLY_CMPGN_DVLP_AMT_FORECAST
-- 상위 top 100 캠페인별 월별 후원개발 금액 예측
-- 기준월을 입력받아 캠페인별 과거 월별 신규·증액·재후원 개발금액을 기반으로 향후 12개월의 캠페인별 월별 후원개발 금액을 예측하는 시계열 모델을 학습하고 예측 결과를 산출한다.
-- 2018년 1월부터 입력 기준월까지의 데이터를 대상으로 최소 24개월 이상의 실적이 존재하고 기준월에도 실적이 있는 캠페인 중 개발금액 합계가 높은 상위 100개 캠페인을 선정하여 학습데이터를 구성한다.
-- 선정된 캠페인별 월간 신규 후원금액, 증액 후원금액, 재후원금액을 합산하여 만원 단위의 월별 개발금액 시계열 데이터를 생성한다.
-- 캠페인(CMPGN_CD)을 시계열 구분 기준으로 설정하여 Snowflake Forecast 모델을 학습한다.
-- 학습된 모델을 이용하여 캠페인별 향후 12개월의 월별 개발금액과 95% 신뢰구간의 하한·상한을 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT 테이블에 기준월별·캠페인별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_MONTHLY_CMPGN_DVLP_AMT_FORECAST(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_MONTHLY_CMPGN_DVLP_AMT_FORECAST';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터 구성 (캠페인별 월별 개발금액 시계열) 신규 증액 재후원
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_DVLP_AMT AS
        SELECT 
            TO_DATE(STDR_MT || ''01'', ''YYYYMMDD'') AS STDR_DE,
            CMPGN_CD,
            ROUND(
                (SUM(NEW_SPNSR_AMT) / 10000) + (SUM(INC_SPNSR_AMT) / 10000) + (SUM(RE_SPNSR_AMT) / 10000)
            , 1) AS DVLP_CNT
        FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
        WHERE STDR_MT BETWEEN ''201801'' AND ''' || :V_STDR_MT || '''
            AND CMPGN_CD IN (
                SELECT CMPGN_CD
                FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
                WHERE STDR_MT BETWEEN ''201801'' AND ''' || :V_STDR_MT || '''
                GROUP BY CMPGN_CD
                HAVING COUNT(DISTINCT STDR_MT) >= 24
                   AND MAX(CASE WHEN STDR_MT = ''' || :V_STDR_MT || ''' THEN 1 ELSE 0 END) = 1
                ORDER BY SUM(NEW_SPNSR_AMT + INC_SPNSR_AMT + RE_SPNSR_AMT) DESC
                LIMIT 100
            )
        GROUP BY STDR_MT, CMPGN_CD
        ORDER BY STDR_DE
        ';

        -- =============================================================================
        -- STEP 2: FORECAST 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.FORECAST GN_DW.ML.MONTHLY_CMPGN_DVLP_AMT_FORECAST_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_DVLP_AMT'),
            SERIES_COLNAME => 'CMPGN_CD',
            TIMESTAMP_COLNAME => 'STDR_DE',
            TARGET_COLNAME => 'DVLP_CNT'
        );

        -- =============================================================================
        -- STEP 3: 결과 테이블 (없으면 CREATE, 있으면 DELETE+INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT (
            STDR_MT VARCHAR COMMENT '예측 실행 기준월 (YYYYMM)',
            CMPGN_CD VARCHAR COMMENT '캠페인코드 (CMPGN_CD)',
            TS TIMESTAMP_NTZ COMMENT '예측 기준일 (월 시작일)',
            FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
            LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
            UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
        )
        COMMENT = '캠페인(CMPGN_CD)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 실행 및 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            SERIES AS CMPGN_CD,
            TS,
            FORECAST,
            LOWER_BOUND,
            UPPER_BOUND
        FROM TABLE(GN_DW.ML.MONTHLY_CMPGN_DVLP_AMT_FORECAST_MODEL!FORECAST(
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
