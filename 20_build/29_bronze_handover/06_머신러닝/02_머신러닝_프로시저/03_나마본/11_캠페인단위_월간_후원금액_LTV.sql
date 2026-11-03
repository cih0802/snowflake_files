
-- =============================================================================
-- 프로시져: 캠페인(CMPGN_CD) 단위 월간 후원금액 LTV 예측. 후원금액 상위 50개
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 가장 높은 LTV 창출하는 캠페인 예상 : 나마본19
-- GN_DW.ML.CMPGN_SPNSR_AMT_LTV_FORECAST_MODEL
-- 캠페인별 월간 후원금액 예측
-- 기준월을 입력받아 캠페인별 과거 월간 후원금액을 기반으로 향후 12개월의 캠페인별 월간 후원금액을 예측하는 시계열 모델을 학습하고 예측 결과를 산출한다.
-- 기준월에 실적이 존재하고 최소 24개월 이상의 월별 데이터가 있는 캠페인을 대상으로 하며, 전체 캠페인 중 누적 후원금액이 높은 상위 50개 캠페인을 선정하여 학습데이터를 구성한다.
-- 2024년 1월부터 입력 기준월까지의 캠페인별 월간 후원금액을 집계하여 캠페인(CMPGN_CD)별 월간 후원금액 시계열 데이터를 생성한다.
-- 캠페인을 시계열 구분 기준으로 설정하여 Snowflake Forecast 모델을 학습한다.
-- 학습된 모델을 이용하여 향후 12개월의 캠페인별 월간 후원금액과 95% 신뢰구간의 하한·상한을 산출한다.
-- 산출된 예측 결과는 GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV 테이블에 기준월별·캠페인별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 별도로 작성된 LTV 산출 로직은 현재 주석 처리되어 있어 현 프로시저에서는 캠페인별 월간 후원금액 예측 결과만 산출·저장한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_CMPGN_SPNSR_AMT_LTV_FORECAST(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_CMPGN_SPNSR_AMT_LTV_FORECAST';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터 구성 (캠페인 채널별 월별 후원금액 시계열)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_AVG_AMT AS
        SELECT 
            CMPGN_CD, 
            STDR_DE, 
            ROUND(SUM(STDR_MT_SPNSR_AMT)) AS SPNSR_AMT
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
        AND CMPGN_CD IN (
            SELECT CMPGN_CD
            FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
            WHERE STDR_MT BETWEEN ''202201'' AND ''' || :V_STDR_MT || '''
            GROUP BY CMPGN_CD
            ORDER BY SUM(STDR_MT_SPNSR_AMT) DESC
            LIMIT 50
        )
        GROUP BY CMPGN_CD, STDR_DE
        ORDER BY CMPGN_CD, STDR_DE
        ';
        
        -- =============================================================================
        -- STEP 2: FORECAST 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.FORECAST GN_DW.ML.CMPGN_SPNSR_AMT_LTV_FORECAST_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_AVG_AMT'),
            SERIES_COLNAME => 'CMPGN_CD',
            TIMESTAMP_COLNAME => 'STDR_DE',
            TARGET_COLNAME => 'SPNSR_AMT'
        );

        -- =============================================================================
        -- STEP 3: 결과 테이블1 (ML_RST_DATA_CMPGN_SPNSR_AMT_LTV) - 없으면 생성, 있으면 DELETE+INSERT
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV (
            STDR_MT VARCHAR COMMENT '예측 실행 기준월 (YYYYMM)',
            MKTG_CHANNEL VARCHAR COMMENT '캠페인 채널 코드 (MKTG_CHANNEL)',
            TS TIMESTAMP_NTZ COMMENT '예측 기준일 (월 시작일)',
            FORECAST FLOAT COMMENT '예측 월간 후원금액',
            LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
            UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
        )
        COMMENT = '채널(MKTG_CHANNEL)별 월간 후원금액 향후 12개월 예측 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 예측 실행 및 INSERT
        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            SERIES AS MKTG_CHANNEL,
            TS,
            FORECAST,
            LOWER_BOUND,
            UPPER_BOUND
        FROM TABLE(GN_DW.ML.CMPGN_SPNSR_AMT_LTV_FORECAST_MODEL!FORECAST(
            FORECASTING_PERIODS => 12
        ))
        ';

        -- =============================================================================
        -- STEP 4: 결과 테이블2 (ML_RST_DATA_CMPGN_LTV_SCORE) - LTV 산출
        -- =============================================================================
        -- CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE (
        --     STDR_MT VARCHAR COMMENT '예측 실행 기준월 (YYYYMM)',
        --     CMPGN_CD VARCHAR COMMENT '캠페인코드',
        --     HIST_TOTAL_AMT FLOAT COMMENT '과거 누적 후원금액 합계 (학습 기간 전체)',
        --     FUTURE_TOTAL_AMT FLOAT COMMENT '향후 12개월 예측 금액 합계',
        --     LTV FLOAT COMMENT '장기가치 (과거 누적 + 향후 예측)',
        --     AVG_MONTHLY_FORECAST FLOAT COMMENT '향후 월평균 예측 금액',
        --     ACTIVE_MONTHS NUMBER COMMENT '과거 활성 월수',
        --     AVG_MONTHLY_ACTUAL FLOAT COMMENT '과거 월평균 실제 금액'
        -- )
        -- COMMENT = '캠페인(CMPGN_CD)별 LTV(장기가치) 산출 결과 (과거 누적 + 향후 예측)';

        -- -- 기존 동일 STDR_MT 데이터 삭제
        -- EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- -- LTV 산출 및 INSERT
        -- EXECUTE IMMEDIATE '
        -- INSERT INTO GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE
        -- SELECT 
        --     ''' || :V_STDR_MT || ''' AS STDR_MT,
        --     h.CMPGN_CD,
        --     h.HIST_TOTAL_AMT,
        --     f.FUTURE_TOTAL_AMT,
        --     h.HIST_TOTAL_AMT + f.FUTURE_TOTAL_AMT AS LTV,
        --     f.FUTURE_TOTAL_AMT / 12 AS AVG_MONTHLY_FORECAST,
        --     h.ACTIVE_MONTHS,
        --     ROUND(h.HIST_TOTAL_AMT / h.ACTIVE_MONTHS, 0) AS AVG_MONTHLY_ACTUAL
        -- FROM (
        --     SELECT 
        --         CMPGN_CD,
        --         SUM(SPNSR_AMT) AS HIST_TOTAL_AMT,
        --         COUNT(DISTINCT STDR_DE) AS ACTIVE_MONTHS
        --     FROM GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_AVG_AMT
        --     GROUP BY CMPGN_CD
        -- ) h
        -- JOIN (
        --     SELECT 
        --         SERIES AS CMPGN_CD,
        --         SUM(FORECAST) AS FUTURE_TOTAL_AMT
        --     FROM GN_DW.ML.ML_RST_DATA_CMPGN_LTV
        --     WHERE STDR_MT = ''' || :V_STDR_MT || '''
        --     GROUP BY SERIES
        -- ) f ON h.CMPGN_CD = f.CMPGN_CD
        -- ';

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

-- =============================================================================
-- 실행 예시
-- =============================================================================
CALL GN_DW.ML.SP_CMPGN_SPNSR_AMT_LTV_FORECAST('202606');           -- 이전달 자동

-- 로그 확인
SELECT * FROM GN_DW.ML.ML_PROCEDURE_LOG WHERE PROC_NAME = 'SP_CMPGN_SPNSR_AMT_LTV_FORECAST' ORDER BY START_TIME DESC;
