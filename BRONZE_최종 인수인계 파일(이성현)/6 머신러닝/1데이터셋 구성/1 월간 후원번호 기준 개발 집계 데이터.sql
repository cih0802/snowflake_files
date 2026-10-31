-- 캠페인별 월간 집계 프로시저
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_MONTHLY_DEV_AMT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_MONTHLY_DEV_AMT';
    
    BEGIN
        CREATE OR REPLACE TABLE GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT (
            STDR_MT            VARCHAR  ,
            STDR_DE            DATE ,     
            MBER_NO            VARCHAR  ,
            SPNSR_NO           VARCHAR  ,
            SPNSR_BSNS_NO      VARCHAR  ,
            SPNSR_BSNS_ID      VARCHAR  ,
            CMPGN_CD           VARCHAR  ,
            UPPER_CMPGN_CD           VARCHAR  ,
            ACMSLT_DEPT_CD          VARCHAR,
            CMPGN_CTGR_CD           VARCHAR  ,
            MKTG_CHANNEL            VARCHAR ,
            STDR_MT_DVLP_DIV_CD           VARCHAR  ,
            FIRST_OCCRRNC_DE   VARCHAR  ,
            LAST_OCCRRNC_DE   VARCHAR  ,
            CANCL_RDCAMT_RSN_CD   VARCHAR  ,
            CHN_CNT NUMBER,
            NEW_CNT NUMBER,
            INC_CNT NUMBER,
            DEC_CNT NUMBER,
            RE_CNT  NUMBER,
            CANCL_CNT NUMBER,
            NEW_SPNSR_AMT      NUMBER   ,
            INC_SPNSR_AMT      NUMBER   ,
            DEC_SPNSR_AMT      NUMBER   ,
            RE_SPNSR_AMT      NUMBER   ,
            CANCL_SPNSR_AMT      NUMBER   ,
            STDR_MT_SPNSR_AMT      NUMBER
        );
        --월별 후원별 상태
        INSERT INTO GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT (
            STDR_MT,     
            STDR_DE,     
            MBER_NO,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            SPNSR_BSNS_ID,
            CMPGN_CD,
            UPPER_CMPGN_CD,
            ACMSLT_DEPT_CD,
            CMPGN_CTGR_CD,
            MKTG_CHANNEL,
            STDR_MT_DVLP_DIV_CD,
            FIRST_OCCRRNC_DE,
            LAST_OCCRRNC_DE,
            CANCL_RDCAMT_RSN_CD,
            CHN_CNT,
            NEW_CNT,
            INC_CNT,
            DEC_CNT,
            RE_CNT,
            CANCL_CNT,
            NEW_SPNSR_AMT,
            INC_SPNSR_AMT,
            DEC_SPNSR_AMT,
            RE_SPNSR_AMT,
            CANCL_SPNSR_AMT,
            STDR_MT_SPNSR_AMT
        )
        WITH
        /* 원본 상세 데이터 */
        BASE AS (
            SELECT
                a.MBER_NO, a.SPNSR_NO, a.SPNSR_BSNS_NO, a.SPNSR_BSNS_ID,
                a.CMPGN_CD, b.UPPER_CMPGN_CD, b.CMPGN_CTGR_CD, b.MKTG_CHANNEL,
                a.ACMSLT_DEPT_CD,
                a.DVLP_DIV_CD, a.OCCRRNC_DE, a.SPNSR_AMT,
                a.CANCL_RDCAMT_RSN_CD
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT a
            LEFT OUTER JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG b
                ON a.CMPGN_CD = b.CMPGN_CD
            WHERE a.OCCRRNC_DE <= :V_STDR_MT_EDAY
        ),
        /* 그룹별 요약: 시작/종료월 + 활동상태 판별 */
        GRP_SUMMARY AS (
            SELECT
                MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID, 
                MIN(LEFT(OCCRRNC_DE, 6)) AS FIRST_MT,
                MAX(LEFT(OCCRRNC_DE, 6)) AS LAST_MT,
                SUM(SPNSR_AMT) AS TOTAL_SPNSR_AMT,
                MAX(CANCL_RDCAMT_RSN_CD) AS CANCL_RSN_CD
            FROM BASE
            GROUP BY MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID
        ),
        
        /* 종료월 결정: 후원중이면 현재월까지 연장 */
        GRP_RANGE AS (
            SELECT *,
                CASE
                    WHEN CANCL_RSN_CD IS NOT NULL OR TOTAL_SPNSR_AMT = 0
                    THEN LAST_MT                -- 종료: LAST_OCCRRNC_DE까지만
                    ELSE :V_STDR_MT               -- 후원중: 현재월까지 연장
                END AS END_MT
            FROM GRP_SUMMARY
        ),
        /* 월 시리즈 생성 (FIRST_MT ~ END_MT) */
        MONTH_SERIES (MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID, FIRST_MT, END_MT, STDR_MT) AS (
            SELECT MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID, 
                   FIRST_MT, END_MT, FIRST_MT
            FROM GRP_RANGE
            UNION ALL
            SELECT MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, SPNSR_BSNS_ID, 
                   FIRST_MT, END_MT,
                   TO_CHAR(DATEADD(MONTH, 1, TO_DATE(STDR_MT || '01', 'YYYYMMDD')), 'YYYYMM')
            FROM MONTH_SERIES
            WHERE STDR_MT < END_MT
        )
        /* 최종: 월별 누적 집계 */
        SELECT
            M.STDR_MT,
            TO_DATE(M.STDR_MT || '01', 'YYYYMMDD') AS STDR_DE,
            M.MBER_NO,
            M.SPNSR_NO,
            M.SPNSR_BSNS_NO,
            M.SPNSR_BSNS_ID,
            --기본 속성 항목
            MAX(B.CMPGN_CD) AS CMPGN_CD,
            MAX(B.UPPER_CMPGN_CD) AS UPPER_CMPGN_CD,
            MAX(B.ACMSLT_DEPT_CD) AS ACMSLT_DEPT_CD,
            MAX(B.CMPGN_CTGR_CD) AS CMPGN_CTGR_CD,
            MAX(B.MKTG_CHANNEL) AS MKTG_CHANNEL,
            -- MAX(B.DVLP_DIV_CD) AS STDR_MT_DVLP_DIV_CD,
            COALESCE(MAX(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT THEN B.DVLP_DIV_CD END)::INT, 6) AS STDR_MT_DVLP_DIV_CD,
            -- MAX(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT THEN B.DVLP_DIV_CD ELSE 6 END) AS STDR_MT_DVLP_DIV_CD,
            --MAX_BY(B.DVLP_DIV_CD, B.OCCRRNC_DE) AS STDR_MT_DVLP_DIV_CD,
            MIN(B.OCCRRNC_DE) AS FIRST_OCCRRNC_DE,
            MAX(B.OCCRRNC_DE) AS LAST_OCCRRNC_DE,
            MAX(B.CANCL_RDCAMT_RSN_CD) AS CANCL_RDCAMT_RSN_CD,
            -- DVLP_DIV_CD 구분별 건수/금액 집계
            -- COUNT(*) - 1 AS CHN_CNT,
            COUNT(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT THEN 1 END) AS CHN_CNT,
            COUNT(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 1 THEN 1 END) AS NEW_CNT,
            COUNT(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 2 THEN 1 END) AS INC_CNT,
            COUNT(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 3 THEN 1 END) AS DEC_CNT,
            COUNT(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 4 THEN 1 END) AS RE_CNT,
            COUNT(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 5 THEN 1 END) AS CANCL_CNT,
            SUM(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 1 THEN B.SPNSR_AMT ELSE 0 END) AS NEW_SPNSR_AMT,
            SUM(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 2 THEN B.SPNSR_AMT ELSE 0 END) AS INC_SPNSR_AMT,
            SUM(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 3 THEN B.SPNSR_AMT ELSE 0 END) AS DEC_SPNSR_AMT,
            SUM(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 4 THEN B.SPNSR_AMT ELSE 0 END) AS RE_SPNSR_AMT,
            SUM(CASE WHEN LEFT(B.OCCRRNC_DE, 6) = M.STDR_MT AND B.DVLP_DIV_CD = 5 THEN B.SPNSR_AMT ELSE 0 END) AS CANCL_SPNSR_AMT,
            SUM(B.SPNSR_AMT) AS STDR_MT_SPNSR_AMT
        FROM MONTH_SERIES M
        JOIN BASE B
            ON  M.MBER_NO       = B.MBER_NO
            AND M.SPNSR_NO      = B.SPNSR_NO
            AND M.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
            AND M.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
            AND LEFT(B.OCCRRNC_DE, 6) <= M.STDR_MT
        GROUP BY
            M.STDR_MT, M.MBER_NO, M.SPNSR_NO, M.SPNSR_BSNS_NO, M.SPNSR_BSNS_ID
        ORDER BY
            M.MBER_NO, M.SPNSR_NO, M.SPNSR_BSNS_NO, M.SPNSR_BSNS_ID, M.STDR_MT;
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
