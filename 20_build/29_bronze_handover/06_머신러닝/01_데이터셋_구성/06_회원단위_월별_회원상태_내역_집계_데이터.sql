-- 회원 상태 변경 이력 스냅샷 및 유효기간 산출
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_MBER_MONTHLY_INFO(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_MBER_MONTHLY_INFO';
    
    BEGIN
        -- 인입쿼리 시작
        CREATE OR REPLACE TABLE GN_DW.ML.MBER_MONTHLY_INFO (
            STDR_MT         VARCHAR  ,
            STDR_DE         DATE,
            MBER_NO            VARCHAR  ,
            SLRCLD_LRR_CD       VARCHAR,
            ACT_DEPT_CD     VARCHAR,
            JOIN_PATH_CD        VARCHAR,
            SEX     VARCHAR,
            STDR_MT_MBER_STAT_CD           VARCHAR  ,
            SER_NO      VARCHAR  ,
            BF_STAT_CD      VARCHAR ,  
            CHN_STAT_CD      VARCHAR ,  
            STAT_START_DT  DATETIME,
            STAT_END_DT           DATETIME,
            FRST_REGIST_DT        DATETIME,
            MONTHS_SINCE_JOIN NUMBER
        );
        
        INSERT INTO GN_DW.ML.MBER_MONTHLY_INFO (
            STDR_MT,
            STDR_DE,
            MBER_NO,
            SLRCLD_LRR_CD,
            ACT_DEPT_CD,
            JOIN_PATH_CD,
            SEX,
            STDR_MT_MBER_STAT_CD,
            SER_NO,
            BF_STAT_CD,  
            CHN_STAT_CD,  
            STAT_START_DT,
            STAT_END_DT,
            FRST_REGIST_DT,
            MONTHS_SINCE_JOIN
        )
        WITH STAT_HIST AS (
            SELECT 
                M.MBER_NO,
                M.SLRCLD_LRR_CD,
                M.ACT_DEPT_CD,
                M.JOIN_PATH_CD,
                M.SEX,
                H.SER_NO,
                H.BF_STAT_CD,
                H.CHN_STAT_CD,
                M.FRST_REGIST_DT AS FRST_REGIST_DT,
                H.CNG_START_DT AS STAT_START_DT,
                CASE 
                    WHEN H.NEXT_REGIST_DT IS NOT NULL 
                         THEN H.NEXT_REGIST_DT
                    WHEN M.MBER_STAT_CD = '12' 
                         THEN H.CNG_START_DT
                END AS STAT_END_DT
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
            JOIN (
                SELECT 
                    MBER_NO, SER_NO, BF_STAT_CD, CHN_STAT_CD,
                    FRST_REGIST_DT,
                    FRST_REGIST_DT AS CNG_START_DT,
                    LEAD(FRST_REGIST_DT) OVER (
                        PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT, SER_NO
                    ) AS NEXT_REGIST_DT
                FROM (
                    SELECT MBER_NO, 0 AS SER_NO, CAST(NULL AS VARCHAR) AS BF_STAT_CD,
                           '1' AS CHN_STAT_CD, FRST_REGIST_DT
                    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
                    UNION ALL
                    SELECT MBER_NO, SER_NO, BF_STAT_CD, CHN_STAT_CD, FRST_REGIST_DT
                    FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
                ) COMBINED_HIST
            ) H ON M.MBER_NO = H.MBER_NO
        ),
        MONTH_SERIES (MBER_NO, SLRCLD_LRR_CD, ACT_DEPT_CD, JOIN_PATH_CD, SEX, FRST_REGIST_DT, SER_NO, BF_STAT_CD, CHN_STAT_CD, STAT_START_DT, STAT_END_DT, STDR_MT) AS (
            SELECT MBER_NO, SLRCLD_LRR_CD, ACT_DEPT_CD, JOIN_PATH_CD, SEX, FRST_REGIST_DT, SER_NO, BF_STAT_CD, CHN_STAT_CD, STAT_START_DT, STAT_END_DT,
                   TO_CHAR(STAT_START_DT, 'YYYYMM')
            FROM STAT_HIST
            UNION ALL
            SELECT MBER_NO, SLRCLD_LRR_CD, ACT_DEPT_CD, JOIN_PATH_CD, SEX, FRST_REGIST_DT, SER_NO, BF_STAT_CD, CHN_STAT_CD, STAT_START_DT, STAT_END_DT,
                   TO_CHAR(DATEADD(MONTH, 1, TO_DATE(STDR_MT || '01', 'YYYYMMDD')), 'YYYYMM')
            FROM MONTH_SERIES
            WHERE DATEADD(MONTH, 1, TO_DATE(STDR_MT || '01', 'YYYYMMDD')) < DATE_TRUNC('MONTH', STAT_END_DT)
              AND STDR_MT < TO_CHAR(CURRENT_DATE(), 'YYYYMM')
        )
        SELECT 
            STDR_MT AS STDR_MT,
            TO_DATE(STDR_MT || '01', 'YYYYMMDD') AS STDR_DE,
            MBER_NO,
            SLRCLD_LRR_CD,
            ACT_DEPT_CD,
            JOIN_PATH_CD,
            SEX,
            CHN_STAT_CD AS STDR_MT_MBER_STAT_CD,
            SER_NO,
            CASE WHEN TO_CHAR(STAT_START_DT, 'YYYYMM') = STDR_MT THEN BF_STAT_CD END AS BF_STAT_CD,
            CASE WHEN TO_CHAR(STAT_START_DT, 'YYYYMM') = STDR_MT THEN CHN_STAT_CD END AS CHN_STAT_CD,
            STAT_START_DT,
            STAT_END_DT,
            FRST_REGIST_DT,
            DATEDIFF('MONTH', 
                DATE_TRUNC('MONTH', FRST_REGIST_DT), 
                TO_DATE(STDR_MT || '01', 'YYYYMMDD')
            ) AS MONTHS_SINCE_JOIN
        FROM MONTH_SERIES
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY STDR_MT, MBER_NO
            ORDER BY STAT_START_DT DESC, SER_NO DESC
        ) = 1
        ORDER BY MBER_NO, STDR_MT;

        -- 인입쿼리 끝
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





