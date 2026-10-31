--회원별 월별 결제수단
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_MBER_MONTHLY_SETLE_INFO(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_MBER_MONTHLY_SETLE_INFO';
    
    BEGIN
        -- 인입쿼리 시작
        CREATE OR REPLACE TABLE GN_DW.ML.MBER_MONTHLY_SETLE_INFO (
            STDR_MT         VARCHAR  ,
            STDR_DE         DATE,
            MBER_NO            VARCHAR  ,
            SETLE_KEY            VARCHAR  ,
            CPR_DIV_CD           VARCHAR  ,
            STDR_MT_SETLE_CD      VARCHAR  , 
            FRST_REGIST_DT  DATETIME,
            START_DT           DATETIME,
            END_DT        DATETIME
        );
        
        INSERT INTO GN_DW.ML.MBER_MONTHLY_SETLE_INFO (
            STDR_MT,
            STDR_DE,
            MBER_NO,
            SETLE_KEY,
            CPR_DIV_CD,
            STDR_MT_SETLE_CD, 
            FRST_REGIST_DT,
            START_DT,
            END_DT
        )
        -- 1단계: 상태변경 이력 기반 월별 그리드 생성
        WITH STAT_HIST AS (
            SELECT 
                M.MBER_NO,
                M.FRST_REGIST_DT,
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
                    MBER_NO,
                    FRST_REGIST_DT,
                    FRST_REGIST_DT AS CNG_START_DT,
                    LEAD(FRST_REGIST_DT) OVER (
                        PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT, SER_NO
                    ) AS NEXT_REGIST_DT
                FROM (
                    SELECT MBER_NO, 0 AS SER_NO, FRST_REGIST_DT
                    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
                    UNION ALL
                    SELECT MBER_NO, SER_NO, FRST_REGIST_DT
                    FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
                ) COMBINED_HIST
            ) H ON M.MBER_NO = H.MBER_NO
        ),
        MONTH_GRID (MBER_NO, FRST_REGIST_DT, STAT_END_DT, STDR_MT) AS (
            SELECT MBER_NO, FRST_REGIST_DT, STAT_END_DT,
                   TO_CHAR(STAT_START_DT, 'YYYYMM')
            FROM STAT_HIST
            UNION ALL
            SELECT MBER_NO, FRST_REGIST_DT, STAT_END_DT,
                   TO_CHAR(DATEADD(MONTH, 1, TO_DATE(STDR_MT || '01', 'YYYYMMDD')), 'YYYYMM')
            FROM MONTH_GRID
            WHERE (STAT_END_DT IS NULL 
                   OR DATEADD(MONTH, 1, TO_DATE(STDR_MT || '01', 'YYYYMMDD')) < DATE_TRUNC('MONTH', STAT_END_DT))
              AND STDR_MT < TO_CHAR(CURRENT_DATE(), 'YYYYMM')
        ),
        -- 2단계: 결제수단 이력에서 유효기간 산출
        SETLE_HIST AS (
            SELECT 
                MBER_NO, SETLE_KEY, CPR_DIV_CD, SETLE_CD,
                FRST_REGIST_DT AS START_DT,
                LEAD(FRST_REGIST_DT) OVER (
                    PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT, SETLE_KEY
                ) AS END_DT
            FROM (
                SELECT MBER_NO, SETLE_KEY, CPR_DIV_CD, SETLE_CD, FRST_REGIST_DT
                FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
                UNION ALL
                SELECT MBER_NO, SETLE_KEY, CPR_DIV_CD, SETLE_CD, REGIST_DT AS FRST_REGIST_DT
                FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
            ) COMBINED_SETLE
        )
        -- 3단계: 월 그리드에 결제수단 매칭
        SELECT 
            G.STDR_MT AS STDR_MT,
            TO_DATE(G.STDR_MT || '01', 'YYYYMMDD') AS STDR_DE,
            G.MBER_NO,
            S.SETLE_KEY,
            S.CPR_DIV_CD,
            S.SETLE_CD AS STDR_MT_SETLE_CD,
            G.FRST_REGIST_DT,
            S.START_DT,
            S.END_DT
        FROM (
            SELECT DISTINCT MBER_NO, FRST_REGIST_DT, STDR_MT 
            FROM MONTH_GRID
        ) G
        LEFT JOIN SETLE_HIST S 
            ON G.MBER_NO = S.MBER_NO
           AND TO_DATE(G.STDR_MT || '01', 'YYYYMMDD') >= DATE_TRUNC('MONTH', S.START_DT)
           AND (S.END_DT IS NULL 
                OR TO_DATE(G.STDR_MT || '01', 'YYYYMMDD') < DATE_TRUNC('MONTH', S.END_DT))
        ORDER BY G.MBER_NO, G.STDR_MT;

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