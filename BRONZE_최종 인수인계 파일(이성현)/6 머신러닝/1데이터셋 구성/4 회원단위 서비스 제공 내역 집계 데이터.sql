-- 회원별 서비스 내역 집계 프로시저
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_MBER_SERVICE_INFO(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_MBER_SERVICE_INFO';
    
    BEGIN
        -- 인입쿼리 시작
        CREATE OR REPLACE TABLE GN_DW.ML.MBER_SERVICE_INFO (
            SVC_TYPE            VARCHAR  ,
            TYPE1            VARCHAR  ,
            TYPE2           VARCHAR  ,
            TYPE3      VARCHAR  ,
            MBER_NO      VARCHAR  ,
            SVR_DT      VARCHAR
        );
        INSERT INTO GN_DW.ML.MBER_SERVICE_INFO (
            SVC_TYPE,
            TYPE1,
            TYPE2,
            TYPE3,
            MBER_NO,
            SVR_DT
        )
        -- UMS 발송 내역(메세지, 이메일)
        SELECT 
            CASE 
                WHEN a.MSG_TYPE = '1' THEN '메세지'
                WHEN a.MSG_TYPE = '2' THEN '이메일'
            END AS SVC_TYPE,
            c.CD_NM AS TYPE1,
            d.DTL_CD_NM AS TYPE2, 
            e.DTL_CD_NM AS TYPE3, 
            b.MBER_NO,
            TO_VARCHAR(a.SEND_DATE, 'YYYYMMDD') AS SVR_DT
        FROM GN_DW.BRONZE_CRM.SND_REQ_MST a
            INNER JOIN GN_DW.BRONZE_CRM.SND_MEMBER_LIST b ON a.SEQ_NO = b.REQ_SEQ_NO
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_CD c ON a.SEND_GBN_TOP = c.CD_ID
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD d ON c.CD_ID = d.CD_ID AND a.SEND_GBN_MID = d.DTL_CD_ID
            LEFT OUTER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD e ON a.SEND_GBN_TOP = e.CD_ID AND e.DTL_CD_ID = a.SEND_GBN_BOT
        WHERE a.USE_YN = 'Y' 
            AND b.CALL_STATUS IN ('7000', '6600', '1');

        --실제 행사 참여한 정보
        INSERT INTO GN_DW.ML.MBER_SERVICE_INFO (
            SVC_TYPE,
            TYPE1,
            TYPE2,
            TYPE3,
            MBER_NO,
            SVR_DT
        )
        SELECT 
            '행사' as SVC_TYPE, 
            c.DTL_CD_NM AS TYPE1, --행사구분
            NULL AS TYPE2, 
            NULL AS TYPE3,
            b.MBER_NO, 
            b.RCPMNY_DATE AS SVR_DE
            --, b.PARTCPT_STAT_CD --
        FROM GN_DW.BRONZE_CRM.TM_MS_CRMN a
            INNER JOIN GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT b ON a.CRMN_CD = b.CRMN_CD
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD c ON c.CD_ID = 'MS002' AND a.CRMN_DIV_CD = c.DTL_CD_ID
        WHERE a.USE_YN = 'Y' AND b.PARTCPT_STAT_CD = '2'; --MS006 참여상태  1신청 2참여 3불참 4대기 5취소 6대기(결제)            

        --CRM 이메일 발송건
        INSERT INTO GN_DW.ML.MBER_SERVICE_INFO (
            SVC_TYPE,
            TYPE1,
            TYPE2,
            TYPE3,
            MBER_NO,
            SVR_DT
        )
        SELECT 
            '이메일' as SVC_TYPE,
            c.CD_NM as TYPE1, 
            d.DTL_CD_NM as TYPE2, 
            NULL as TYPE3,
            b.MBER_NO, 
            TO_VARCHAR(b.SNDNG_DE, 'YYYYMMDD') AS SVR_DE
        FROM GN_DW.BRONZE_CRM.TM_MS_EMAIL_SNDNG a 
            INNER JOIN GN_DW.BRONZE_CRM.TD_MS_EMAIL_SNDNG_DTLS b ON a.SNDNG_KEY = b.SNDNG_KEY
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_CD c ON a.SNDNG_CD_ID = c.CD_ID
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD d ON c.CD_ID = d.CD_ID AND a.SNDNG_DTL_CD_ID = d.DTL_CD_ID
        WHERE b.SNDNG_RST_CD = '1'; 

        -- 메시지 발송건
        INSERT INTO GN_DW.ML.MBER_SERVICE_INFO (
            SVC_TYPE,
            TYPE1,
            TYPE2,
            TYPE3,
            MBER_NO,
            SVR_DT
        )
        SELECT
            '메세지' as SVC_TYPE,
            c.CD_NM as TYPE1, 
            d.DTL_CD_NM as TYPE2, 
            e.DTL_CD_NM as TYPE3, 
            b.MBER_NO, 
            TO_VARCHAR(b.SNDNG_DT, 'YYYYMMDD') AS SVC_DE
        FROM GN_DW.BRONZE_CRM.TM_MS_MSG_AT_SNDNG a
            INNER JOIN GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS b ON a.SNDNG_KEY = b.SNDNG_KEY    
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_CD c ON a.SNDNG_CD_ID = c.CD_ID
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD d ON a.SNDNG_CD_ID = d.CD_ID AND LEFT(a.SNDNG_DTL_CD_ID, 2) = d.DTL_CD_ID
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD e ON a.SNDNG_CD_ID = e.CD_ID AND a.SNDNG_DTL_CD_ID = e.DTL_CD_ID;

        --이벤트 참여건
        INSERT INTO GN_DW.ML.MBER_SERVICE_INFO (
            SVC_TYPE,
            TYPE1,
            TYPE2,
            TYPE3,
            MBER_NO,
            SVR_DT
        )
        SELECT 
            '이벤트' as SVC_TYPE,
            c.DTL_CD_NM as TYPE1, 
            NULL as TYPE2, 
            NULL as TYPE3, 
            b.MBER_NO, 
            TO_VARCHAR(b.PARTCPT_DT, 'YYYYMMDD') AS SVR_DE,
        FROM GN_DW.BRONZE_CRM.TM_MS_EVENT a
            INNER JOIN GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL b ON a.EVENT_CD = b.EVENT_CD
            INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD c ON c.CD_ID = 'MS286' AND a.EVENT_DIV_CD = c.DTL_CD_ID;
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