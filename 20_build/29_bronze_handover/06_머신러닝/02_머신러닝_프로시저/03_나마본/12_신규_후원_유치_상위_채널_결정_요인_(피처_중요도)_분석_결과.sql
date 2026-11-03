-- =============================================================================
-- 프로시져: 신규 후원 유치 상위 채널 기여 요인 분석
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 신규사용자 확보 상위 채널과 유입 기여도. : 나마본21
-- GN_DW.ML.CHANNEL_NEW_DVLP_CLASSIFIER_MODEL
-- 채널별 신규 후원개발 상위 결정요인 분석
-- 기준월을 입력받아 채널별 캠페인 월간 후원 현황 및 증감 데이터를 기반으로 신규 후원개발이 높은 채널의 특성에 영향을 미치는 주요 요인을 분석하고 피처 중요도를 산출한다.
-- 2022년 1월부터 입력 기준월까지의 캠페인·월 단위 데이터를 대상으로 총 후원건수, 활성 후원건수, 활성률, 증액·감액·재후원·해지 건수, 활성 후원금액 등의 데이터를 활용하여 학습데이터를 구성한다.
-- 신규 후원금액 건수(NEW_AMT_CNT)가 **50건 이상인 경우를 HIGH_NEW_CHANNEL = 1**로 정의하고, 신규 후원개발 수준이 높은 채널의 특성을 분류하는 Snowflake Classification 모델을 학습한다.
-- 학습된 Classification 모델의 SHOW_FEATURE_IMPORTANCE()를 활용하여 신규 후원개발 상위 채널 결정에 영향을 미치는 피처별 중요도 및 순위를 산출한다.
-- 산출된 피처 중요도 결과는 GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION 테이블에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 피처별 중요도 점수(SCORE)와 순위를 저장하여 신규 후원개발이 높은 채널의 주요 특성 및 영향요인을 분석할 수 있도록 한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_CHANNEL_NEW_DVLP_CONTRIBUTION(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_CHANNEL_NEW_DVLP_CONTRIBUTION';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: ML 학습 데이터 구성 (캠페인-월 단위, 신규유치 발생 여부 분류)
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_CHANNEL_SPNSR_DVLP AS
        SELECT 
            MKTG_CHANNEL,
            c.TOT_CNT,
            c.ACT_CNT,
            DIV0NULL(c.ACT_CNT, c.TOT_CNT) AS ACT_RATE,
            c.INC_CNT,
            c.DEC_CNT,
            c.RE_CNT,
            c.CANCL_CNT,
            c.ACT_AMT_CNT,
            DIV0NULL(c.CANCL_CNT, c.TOT_CNT) AS CANCL_RATE,
            DIV0NULL(c.RE_CNT, c.TOT_CNT) AS RE_RATE,
            CASE WHEN c.NEW_AMT_CNT >= 50 THEN 1 ELSE 0 END AS HIGH_NEW_CHANNEL
        FROM GN_DW.ML.CMPGN_MONTHLY_SNAPSHOT c
        WHERE c.STDR_MT BETWEEN ''202201'' AND ''' || :V_STDR_MT || '''
          AND c.TOT_CNT > 0
        ';

        -- =============================================================================
        -- STEP 3: CLASSIFICATION 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.CHANNEL_NEW_DVLP_CLASSIFIER_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'GN_DW.ML.ML_TRAIN_DATA_CHANNEL_SPNSR_DVLP'),
            TARGET_COLNAME => 'HIGH_NEW_CHANNEL',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 4: 결과 테이블 (없으면 생성, 있으면 DELETE+INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION (
            STDR_MT VARCHAR COMMENT '분석 실행 기준월 (YYYYMM)',
            RANK NUMBER COMMENT '피처 중요도 순위',
            FEATURE VARCHAR COMMENT '피처명',
            SCORE FLOAT COMMENT '피처 중요도 점수 (0~1, 합계=1)'
        )
        COMMENT = '신규 후원 유치 상위 채널 결정 요인 (피처 중요도) 분석 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 피처 중요도 호출 및 INSERT
        CALL GN_DW.ML.CHANNEL_NEW_DVLP_CLASSIFIER_MODEL!SHOW_FEATURE_IMPORTANCE();

        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            "RANK",
            "FEATURE",
            "SCORE",
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
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
