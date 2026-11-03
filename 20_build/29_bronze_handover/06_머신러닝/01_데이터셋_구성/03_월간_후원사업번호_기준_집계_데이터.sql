-- 회원별 월별 정기후원내역 스냅샷
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_CMPGN_MBER_SNAPSHOT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_STDR_MT_EDATE VARCHAR := LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD'));
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_CMPGN_MBER_SNAPSHOT';
    
    BEGIN
        -- 인입쿼리 시작
        CREATE OR REPLACE TABLE GN_DW.ML.CMPGN_MBER_SNAPSHOT (
            STDR_DE            DATE     ,     
            MBER_NO            VARCHAR  ,
            SPNSR_NO           VARCHAR  ,
            SPNSR_BSNS_NO      VARCHAR  ,
            CMPGN_CD           VARCHAR  ,
            FIRST_OCCRRNC_DE   VARCHAR  ,
            LAST_OCCRRNC_DE    VARCHAR  ,
            ACMSLT_DEPT_CD     VARCHAR  ,
            FRST_SETLE_CD      VARCHAR  ,
            LAST_SETLE_CD      VARCHAR  ,
            IS_ACTIVE_YN       CHAR     ,
            CUR_SPNSR_AMT      NUMBER   ,
            MINUS_SPNSR_AMT    NUMBER   ,
            PLUS_SPNSR_AMT     BIGINT   ,
            REG_DT             DATE  
        );
        --해당일자 스냅샷 정보
        INSERT INTO GN_DW.ML.CMPGN_MBER_SNAPSHOT (
            STDR_DE
            , MBER_NO
            , SPNSR_NO
            , SPNSR_BSNS_NO
            , CMPGN_CD
            , FIRST_OCCRRNC_DE
            , LAST_OCCRRNC_DE
            , ACMSLT_DEPT_CD
            , FRST_SETLE_CD
            , LAST_SETLE_CD
            , IS_ACTIVE_YN
            , CUR_SPNSR_AMT
            , MINUS_SPNSR_AMT
            , PLUS_SPNSR_AMT
            , REG_DT
        )
        SELECT 
            :V_STDR_MT_EDATE AS STDR_DE
            , MBER_NO
            , SPNSR_NO
            , SPNSR_BSNS_NO
            , CMPGN_CD
            , MIN(OCCRRNC_DE) AS FIRST_OCCRRNC_DE
            , MAX(OCCRRNC_DE) AS LAST_OCCRRNC_DE
            , MAX(ACMSLT_DEPT_CD) AS ACMSLT_DEPT_CD
            , MAX(FRST_SETLE_CD) AS FRST_SETLE_CD
            , MAX(LAST_SETLE_CD) AS LAST_SETLE_CD
            , CASE 
                WHEN MAX(LAST_SPNSR_AMT) <= 0 AND MAX(LAST_CANCL_RSN) IS NOT NULL THEN 'N'
                ELSE 'Y'
              END AS IS_ACTIVE_YN
            , SUM(SPNSR_AMT) AS CUR_SPNSR_AMT
            , SUM(CASE WHEN SPNSR_AMT < 0 THEN SPNSR_AMT ELSE 0 END) AS MINUS_SPNSR_AMT
            , SUM(CASE WHEN SPNSR_AMT > 0 THEN SPNSR_AMT ELSE 0 END) AS PLUS_SPNSR_AMT
            , GETDATE() AS REG_DT
        FROM (
            SELECT 
                MBER_NO
                , SPNSR_NO
                , SPNSR_BSNS_NO
                , CMPGN_CD
                , OCCRRNC_DE
                , ACMSLT_DEPT_CD
                , SPNSR_AMT
                , CANCL_RDCAMT_RSN_CD
                , SER_NO
                , FIRST_VALUE(SETLE_CD) OVER (
                    PARTITION BY MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, CMPGN_CD 
                    ORDER BY SER_NO ASC
                  ) AS FRST_SETLE_CD
                , LAST_VALUE(SETLE_CD) OVER (
                    PARTITION BY MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, CMPGN_CD 
                    ORDER BY SER_NO ASC
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                  ) AS LAST_SETLE_CD
                , LAST_VALUE(SPNSR_AMT) OVER (
                    PARTITION BY MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, CMPGN_CD 
                    ORDER BY SER_NO ASC
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                  ) AS LAST_SPNSR_AMT
                , LAST_VALUE(CANCL_RDCAMT_RSN_CD) OVER (
                    PARTITION BY MBER_NO, SPNSR_NO, SPNSR_BSNS_NO, CMPGN_CD 
                    ORDER BY SER_NO ASC
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                  ) AS LAST_CANCL_RSN
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT a
            WHERE OCCRRNC_DE <= :V_STDR_MT_EDAY
        ) T
        GROUP BY 
            MBER_NO
            , SPNSR_NO
            , SPNSR_BSNS_NO
            , CMPGN_CD;

        -- 입입쿼리 끝
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