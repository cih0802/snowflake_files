-- 회원별 월별 납입내역
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_MBRFEE_PAY_DTLS(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_MBRFEE_PAY_DTLS';
    
    BEGIN
        -- 인입쿼리 시작
        CREATE OR REPLACE TABLE GN_DW.ML.MBRFEE_PAY_DTLS (
            MBRFEE_MT            VARCHAR  ,
            MBER_NO            VARCHAR  ,
            SPNSR_NO           VARCHAR  ,
            SPNSR_BSNS_NO      VARCHAR  ,
            SPNSR_BSNS_ID      VARCHAR  ,
            CMPGN_CD      VARCHAR  ,
            RGR_REQ_AMT      NUMBER   ,
            RGR_PAY_AMT      NUMBER   ,
            GFT_REQ_AMT      NUMBER   ,
            GFT_PAY_AMT      NUMBER   ,
            PAY_SUC_STATUS VARCHAR, 
            SETLE_CD  VARCHAR,
            PAY_DE  DATE,
            RQEST_DE_LIST VARCHAR,
            RQEST_RST_CD_LIST VARCHAR,
            RQEST_SQNC_LIST VARCHAR
        );
        INSERT INTO GN_DW.ML.MBRFEE_PAY_DTLS (
            MBRFEE_MT,
            MBER_NO,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            SPNSR_BSNS_ID,
            CMPGN_CD,
            RGR_REQ_AMT,
            RGR_PAY_AMT,
            GFT_REQ_AMT,
            GFT_PAY_AMT,
            PAY_SUC_STATUS, 
            SETLE_CD,
            PAY_DE,
            RQEST_DE_LIST,
            RQEST_RST_CD_LIST,
            RQEST_SQNC_LIST
        )
        SELECT 
            a.MBRFEE_MT, a.MBER_NO, a.SPNSR_NO, a.SPNSR_BSNS_NO, a.SPNSR_BSNS_ID, b.CMPGN_CD,
            SUM(CASE WHEN a.MBRFEE_DIV_CD = 'E' THEN a.RQEST_AMT ELSE 0 END) AS RGR_REQ_AMT,  
            SUM(CASE WHEN a.MBRFEE_DIV_CD = 'E' THEN a.PAY_AMT ELSE 0 END) AS RGR_PAY_AMT,  
            SUM(CASE WHEN a.MBRFEE_DIV_CD = 'G' THEN a.RQEST_AMT ELSE 0 END) AS GFT_REQ_AMT,  
            SUM(CASE WHEN a.MBRFEE_DIV_CD = 'G' THEN a.PAY_AMT ELSE 0 END) AS GFT_PAY_AMT,
            CASE WHEN count(CASE WHEN a.PAY_STAT_CD = 'S' THEN 1 END) >= 1 THEN 'Y' ELSE 'N' END AS PAY_SUC_STATUS,
            LISTAGG(DISTINCT a.SETLE_CD, ', ') WITHIN GROUP (ORDER BY a.SETLE_CD) AS SETLE_CD_LIST,
            MAX(CASE WHEN a.PAY_STAT_CD = 'S' THEN a.PAY_DE END) AS PAY_DE,
            LISTAGG(a.RQEST_DE::VARCHAR, ',') WITHIN GROUP (ORDER BY a.RQEST_SQNC) AS RQEST_DE_LIST,
            LISTAGG(a.RQEST_RST_CD, ',') WITHIN GROUP (ORDER BY a.RQEST_SQNC) AS RQEST_RST_CD_LIST,
            LISTAGG(a.RQEST_SQNC::VARCHAR, ',') WITHIN GROUP (ORDER BY a.RQEST_SQNC) AS RQEST_SQNC_LIST
            --SUM(PAY_AMT)--, RETUN_RSN_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT a
            INNER JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR b ON a.MBER_NO = b.MBER_NO AND a.SPNSR_NO = b.SPNSR_NO
        WHERE 
            a.USE_YN = 'Y'
            AND a.PRCS_STAT_CD = 'S'
            GROUP BY a.MBRFEE_MT, a.MBER_NO, a.SPNSR_NO, a.SPNSR_BSNS_NO, a.SPNSR_BSNS_ID, b.CMPGN_CD
            ORDER BY a.MBRFEE_MT, a.MBER_NO, a.SPNSR_NO, a.SPNSR_BSNS_NO, a.SPNSR_BSNS_ID, b.CMPGN_CD;

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




















SELECT *
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
WHERE SPNSR_BSNS_NO = '396459'
AND MBRFEE_MT = '201110'
    


--캠페인별 월별 신규, 취소, 활동건 수
SELECT top 10 *
FROM GN_DW.ML.CMPGN_MONTHLY_SNAPSHOT


--SPNSR_BSNS_NO 별 회비월별 회비요청금액, 회비납입그맥, 선물금 요청금액, 선물금 납입금액, 결제방식, 후원사업
--스냅샷 성이 아님. 다만 월이 달라짐에 따라서 결제수단등 데이터가 달라질 수는 있음. 
--마감된 데이터는 정합성 문제가 없다고 가정하고 진행
SELECT top 10 *
FROM GN_DW.ML.MBRFEE_PAY_DTLS
GROUP BY MBR





--이 경우 pay_amt가 -인 건들이 있으며, 승인취소, 계좌환금 등으로 확인됨. 
SELECT 
    top 100 *
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
WHERE RQEST_AMT != PAY_AMT
AND PAY_STAT_CD = 'S' AND PRCS_STAT_CD = 'S'
