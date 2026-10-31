-- 후원중단 고위험군
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_SNPSR_BSNS_NO_DSCNT_ML_DATA(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_SNPSR_BSNS_NO_DSCNT_ML_DATA';
    
    BEGIN
        -- 인입쿼리 시작
        CREATE OR REPLACE TABLE GN_DW.ML.SNPSR_BSNS_NO_DSCNT_ML_DATA (
            MBER_NO            VARCHAR  ,
            FRST_REGIST_DT            DATETIME,
            -- BRTHDY           VARCHAR  ,
            SEX      VARCHAR  ,
            -- ZIP      VARCHAR  ,
            SPNSR_BSNS_NO VARCHAR,
            CMPGN_CD VARCHAR,
            ACT_YN VARCHAR,
            SPNSR_AMT      NUMBER  ,
            DVLP_DIV_CD      VARCHAR   ,
            NEW_SPNSR_AMT      NUMBER   ,
            INC_SPNSR_AMT      NUMBER   ,
            DEC_SPNSR_AMT      NUMBER   ,
            RE_SPNSR_AMT      NUMBER   ,
            CANCL_SPNSR_AMT      NUMBER   ,
            CHN_CNT      NUMBER   ,
            SETLE_CD      VARCHAR   ,
            PAY_CNT NUMBER, 
            NONPAY_CNT  NUMBER
        );
        
        INSERT INTO GN_DW.ML.SNPSR_BSNS_NO_DSCNT_ML_DATA (
            MBER_NO,
            FRST_REGIST_DT,
            -- BRTHDY,
            SEX,
            -- ZIP,
            SPNSR_BSNS_NO,
            CMPGN_CD,
            ACT_YN,
            SPNSR_AMT,
            DVLP_DIV_CD,
            NEW_SPNSR_AMT,
            INC_SPNSR_AMT,
            DEC_SPNSR_AMT,
            RE_SPNSR_AMT,
            CANCL_SPNSR_AMT,
            CHN_CNT,
            SETLE_CD,
            PAY_CNT, 
            NONPAY_CNT
        )
        SELECT 
            a.MBER_NO, 
            a.FRST_REGIST_DT, 
            -- a.BRTHDY, 
            a.SEX, 
            -- a.ZIP, 
            c.SPNSR_BSNS_NO, 
            c.CMPGN_CD, 
            CASE 
                WHEN 
                    c.CANCL_RDCAMT_RSN_CD IS NULL AND
                    c.SPNSR_AMT != 0
                THEN 'Y' 
                ELSE 'N' 
            END as ACT_YN, 
            c.SPNSR_AMT,
            c.DVLP_DIV_CD, 
            c.NEW_SPNSR_AMT,
            c.INC_SPNSR_AMT, 
            c.DEC_SPNSR_AMT, 
            c.RE_SPNSR_AMT, 
            c.CANCL_SPNSR_AMT,
            c.CHN_CNT, 
            b.SETLE_CD, 
            d.PAY_CNT,
            d.NONPAY_CNT
            --'' as alimt_snd_cnt, '' as alimt_open_cnt, '' as mail_open_cnt
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO a
            INNER JOIN GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO b 
                ON a.MBER_NO = b.MBER_NO
                AND 
                    CASE 
                        WHEN a.CPR_DIV_CD = 'A' THEN 'I' 
                        ELSE a.CPR_DIV_CD 
                    END = b.CPR_DIV_CD
            INNER JOIN (
                -- 조회시점 SPNSR_BSNS_NO 별 최종상태 필요. 
                SELECT 
                    MBER_NO, 
                    SPNSR_BSNS_NO, 
                    CMPGN_CD, 
                    MAX_BY(STDR_MT_SPNSR_AMT, STDR_MT) AS SPNSR_AMT,
                    MAX_BY(STDR_MT_DVLP_DIV_CD, STDR_MT) AS DVLP_DIV_CD,
                    MAX_BY(CANCL_RDCAMT_RSN_CD, STDR_MT) AS CANCL_RDCAMT_RSN_CD,
                    SUM(NEW_SPNSR_AMT) AS NEW_SPNSR_AMT,
                    SUM(INC_SPNSR_AMT) AS INC_SPNSR_AMT,
                    SUM(DEC_SPNSR_AMT) AS DEC_SPNSR_AMT,
                    SUM(RE_SPNSR_AMT) AS RE_SPNSR_AMT,
                    SUM(CANCL_SPNSR_AMT) AS CANCL_SPNSR_AMT,
                    SUM(CHN_CNT) AS CHN_CNT
                -- FROM GN_DW.ML.DVLP_AMT_SNAPSHOT
                FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
                GROUP BY MBER_NO, SPNSR_BSNS_NO, CMPGN_CD
            ) c ON a.mber_no = c.mber_no
            LEFT OUTER JOIN (
                SELECT 
                    MBER_NO, 
                    COUNT(CASE WHEN PAY_SUC_STATUS = 'Y' THEN 1 END) as PAY_CNT, 
                    COUNT(CASE WHEN PAY_SUC_STATUS = 'N' THEN 1 END) as NONPAY_CNT
                FROM GN_DW.ML.MBRFEE_PAY_DTLS
                GROUP BY MBER_NO
            ) d ON a.MBER_NO = d.MBER_NO
        WHERE d.MBER_NO IS NOT NULL -- 결제정보를 부분적으로 가져와서 결제정보 없는 건들이 있음. 
        AND NOT (
            ACT_YN = 'Y' AND SPNSR_AMT <= 0 --2건 존재
        );

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