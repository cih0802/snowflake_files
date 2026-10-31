-- =============================================================================
-- 프로시져: 후원개발 증가를 위한 우선 개선 요인 분석
-- 파라미터: P_STDR_MT (YYYYMM, NULL이면 실행시점 이전달)
-- 웨어하우스: GN_DW_ML_WH (STATEMENT_TIMEOUT 15분)
-- =============================================================================
-- 회원개발 증가시기기 위한 영향 요인 : 나마본6
-- GN_DW.ML.SP_DVLP_INC_CONTRIBUTION
-- 후원개발 증대 기여요인 분석
-- 기준월을 입력받아 캠페인별 월간 후원개발 현황 및 증감 데이터를 기반으로 신규 후원개발 발생 여부에 영향을 미치는 주요 요인을 분석하고 피처 중요도를 산출한다.
-- 2022년 1월부터 입력 기준월까지의 캠페인별 월간 데이터를 대상으로 총 후원건수, 활성 후원건수, 활성률, 증액·감액·재후원·해지 건수, 활성 후원금액 등의 데이터를 활용하여 학습데이터를 구성한다.
-- 신규 후원개발 건수가 발생한 경우를 HAS_NEW_DVLP = 1로 정의하고, 신규 후원개발 발생 여부를 예측하는 Snowflake Classification 모델을 학습한다.
-- 학습된 Classification 모델의 SHOW_FEATURE_IMPORTANCE()를 활용하여 신규 후원개발 발생에 영향을 미치는 피처별 중요도 및 순위를 산출한다.
-- 산출된 피처 중요도 결과는 GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION 테이블에 기준월별로 저장하며, 동일 기준월의 기존 결과는 삭제 후 재적재한다.
-- 피처별 중요도 점수(SCORE)는 모델에서 제공하는 값을 저장하며, 피처명, 순위, 피처 유형을 함께 관리한다.
-- 처리 성공·실패 여부, 수행시간 및 오류 내용을 ML_PROCEDURE_LOG에 기록한다.

CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_DVLP_INC_CONTRIBUTION(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_DVLP_INC_CONTRIBUTION';

    BEGIN
        -- 웨어하우스 설정 (15분 타임아웃)
        ALTER WAREHOUSE GN_DW_ML_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
        USE WAREHOUSE GN_DW_ML_WH;

        -- =============================================================================
        -- STEP 1: 학습 데이터 구성
        -- =============================================================================
        EXECUTE IMMEDIATE '
        CREATE OR REPLACE TABLE GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_DVLP AS
        SELECT 
            c.CMPGN_CD,
            c.STDR_MT,
            c.TOT_CNT,
            c.ACT_CNT,
            DIV0NULL(c.ACT_CNT, c.TOT_CNT) AS ACT_RATE,
            c.INC_CNT,
            c.DEC_CNT,
            c.RE_CNT,
            c.CANCL_CNT,
            c.ACT_AMT_CNT,
            DIV0NULL(c.CANCL_CNT, c.TOT_CNT) AS CANCL_RATE,
            DIV0NULL(c.INC_CNT, c.ACT_CNT) AS INC_RATE,
            DIV0NULL(c.RE_CNT, c.TOT_CNT) AS RE_RATE,
            CASE WHEN c.NEW_CNT > 0 THEN 1 ELSE 0 END AS HAS_NEW_DVLP
        FROM GN_DW.ML.CMPGN_MONTHLY_SNAPSHOT c
        WHERE c.STDR_MT BETWEEN ''202201'' AND ''' || :V_STDR_MT || '''
          AND c.TOT_CNT > 0
        ';

        -- =============================================================================
        -- STEP 2: 학습용 뷰 (ID 컬럼 제외)
        -- =============================================================================
        CREATE OR REPLACE VIEW GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_DVLP_V AS
        SELECT * EXCLUDE (CMPGN_CD, STDR_MT)
        FROM GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_DVLP;

        -- =============================================================================
        -- STEP 3: CLASSIFICATION 모델 학습
        -- =============================================================================
        CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION GN_DW.ML.CMPGN_DVLP_CLASSIFIER_MODEL(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'GN_DW.ML.ML_TRAIN_DATA_MONTHLY_CMPGN_DVLP_V'),
            TARGET_COLNAME => 'HAS_NEW_DVLP',
            CONFIG_OBJECT => {'ON_ERROR': 'SKIP'}
        );

        -- =============================================================================
        -- STEP 4: 결과 테이블 (없으면 생성, 있으면 DELETE+INSERT)
        -- =============================================================================
        CREATE TABLE IF NOT EXISTS GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION (
            STDR_MT VARCHAR COMMENT '분석 실행 기준월 (YYYYMM)',
            RANK NUMBER COMMENT '피처 중요도 순위',
            FEATURE VARCHAR COMMENT '피처명',
            SCORE FLOAT COMMENT '피처 중요도 점수 (0~1, 합계=1)',
            FEATURE_TYPE VARCHAR COMMENT '피처 유형 (user_provided)'
        )
        COMMENT = '후원개발 20% 증가를 위한 우선 개선 요인 (피처 중요도) 분석 결과';

        -- 기존 동일 STDR_MT 데이터 삭제
        EXECUTE IMMEDIATE 'DELETE FROM GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION WHERE STDR_MT = ''' || :V_STDR_MT || '''';

        -- 피처 중요도 호출 및 INSERT
        CALL GN_DW.ML.CMPGN_DVLP_CLASSIFIER_MODEL!SHOW_FEATURE_IMPORTANCE();

        EXECUTE IMMEDIATE '
        INSERT INTO GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION
        SELECT 
            ''' || :V_STDR_MT || ''' AS STDR_MT,
            "RANK",
            "FEATURE",
            "SCORE",
            "FEATURE_TYPE"
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
