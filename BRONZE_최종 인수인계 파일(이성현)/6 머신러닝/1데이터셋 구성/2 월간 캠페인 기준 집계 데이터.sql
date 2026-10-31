--캠페인별 기준월별 누적 개발건수 / 해당월 신규 / 해당월 중단 / 해당월 재후원 / 해당월 감액 / 해당월 중단 건수 집계 프로시저
CREATE OR REPLACE PROCEDURE GN_DW.ML.SP_INSERT_ML_DATASET_CMPGN_MONTHLY_SNAPSHOT(P_STDR_MT VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    -- 변수 선언
    LET V_STDR_MT VARCHAR := COALESCE(P_STDR_MT, TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'));
    LET V_STDR_MT_EDAY VARCHAR := TO_CHAR(LAST_DAY(TO_DATE(P_STDR_MT || '01', 'YYYYMMDD')), 'YYYYMMDD');
    LET V_START_TIME TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    LET V_PROC_NAME VARCHAR := 'SP_INSERT_ML_DATASET_CMPGN_MONTHLY_SNAPSHOT';
    
    BEGIN
        CREATE OR REPLACE TABLE GN_DW.ML.CMPGN_MONTHLY_SNAPSHOT (
            CMPGN_CD            VARCHAR  ,     
            UPPER_CMPGN_CD            VARCHAR  ,  
            MKTG_CHANNEL            VARCHAR  ,  
            STDR_MT            VARCHAR  ,
            STDR_DE             DATE,
            TOT_CNT           NUMBER  ,
            NEW_CNT           NUMBER  ,
            INC_CNT           NUMBER  ,
            DEC_CNT           NUMBER  ,
            RE_CNT           NUMBER  ,
            CANCL_CNT           NUMBER  ,
            ACT_CNT             NUMBER, 
            NEW_AMT_CNT             NUMBER(38,6), 
            INC_AMT_CNT             NUMBER(38,6), 
            DEC_AMT_CNT             NUMBER(38,6), 
            RE_AMT_CNT             NUMBER(38,6), 
            CANCL_AMT_CNT             NUMBER(38,6), 
            ACT_AMT_CNT             NUMBER(38,6)
        );
        INSERT INTO GN_DW.ML.CMPGN_MONTHLY_SNAPSHOT (
            CMPGN_CD,  
            UPPER_CMPGN_CD,
            MKTG_CHANNEL,
            STDR_MT,
            STDR_DE,
            TOT_CNT,
            NEW_CNT,
            INC_CNT,
            DEC_CNT,
            RE_CNT,
            CANCL_CNT,
            ACT_CNT,
            NEW_AMT_CNT,
            INC_AMT_CNT,
            DEC_AMT_CNT,
            RE_AMT_CNT,
            CANCL_AMT_CNT,
            ACT_AMT_CNT
        )
        SELECT 
            M.CMPGN_CD,
            M.UPPER_CMPGN_CD,
            M.MKTG_CHANNEL,
            M.YYYYMM AS STDR_MT,
            TO_DATE(M.YYYYMM || '01', 'YYYYMMDD') AS STDR_DE,
            COUNT(S.CMPGN_CD) AS TOT_CNT,
            -- 1. 해당 월(YYYYMM)이 최초 발생월인 신규 건수
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 1 THEN 1 
                    ELSE 0 
                END
            ) AS NEW_CNT,
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 2 THEN 1 
                    ELSE 0 
                END
            ) AS INC_CNT,
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 3 THEN 1 
                    ELSE 0 
                END
            ) AS DEC_CNT,
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 4 THEN 1 
                    ELSE 0 
                END
            ) AS RE_CNT,
            -- 2. 해당 월(YYYYMM)이 최종 발생월이면서 중단(DVLP_DIV_CD = 5)인 건수
            SUM(
                CASE 
                    WHEN SUBSTR(S.LAST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.CANCL_RDCAMT_RSN_CD IS NOT NULL THEN 1 
                    ELSE 0 
                END
            ) AS CANCL_CNT,
            -- 3. 이번 달 신규도 아니고 중단도 아닌 순수 유지/진행 건수
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) != M.YYYYMM 
                     AND NOT (SUBSTR(S.LAST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND (S.STDR_MT_DVLP_DIV_CD = 5 or S.STDR_MT_SPNSR_AMT = 0)) THEN 1  --종료월이 해당월이면서 
                    ELSE 0 
                END
            ) AS ACT_CNT,
            -- 1. 해당 월(YYYYMM)이 최초 발생월인 신규 건수
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 1 THEN S.NEW_SPNSR_AMT
                    ELSE 0 
                END
            ) / 10000 AS NEW_AMT_CNT,
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 2 THEN S.NEW_SPNSR_AMT
                    ELSE 0 
                END
            ) / 10000 AS INC_AMT_CNT,
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 3 THEN S.NEW_SPNSR_AMT
                    ELSE 0 
                END
            ) / 10000 AS DEC_AMT_CNT,
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 4 THEN S.NEW_SPNSR_AMT
                    ELSE 0 
                END
            ) / 10000 AS RE_AMT_CNT,
            -- 2. 해당 월(YYYYMM)이 최종 발생월이면서 중단(DVLP_DIV_CD = 5)인 건수
            SUM(
                CASE 
                    WHEN SUBSTR(S.LAST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.CANCL_RDCAMT_RSN_CD IS NOT NULL THEN S.CANCL_SPNSR_AMT
                    ELSE 0 
                END
            ) / 10000 AS CANCL_AMT_CNT,
            -- 3. 이번 달 신규도 아니고 중단도 아닌 순수 유지/진행 건수
            SUM(
                CASE 
                    WHEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) != M.YYYYMM 
                     AND NOT (SUBSTR(S.LAST_OCCRRNC_DE, 1, 6) = M.YYYYMM AND S.STDR_MT_DVLP_DIV_CD = 5) THEN S.STDR_MT_SPNSR_AMT
                    ELSE 0 
                END
            ) / 10000 AS ACT_AMT_CNT
        FROM (
            -- 3. 캠페인별로 시작월부터 종료월까지 월(YYYYMM) 단위 행 생성
            SELECT 
                P.CMPGN_CD, P.UPPER_CMPGN_CD, P.MKTG_CHANNEL,
                TO_CHAR(DATEADD(month, G.SEQ, P.START_DATE), 'YYYYMM') AS YYYYMM
            FROM (
                -- 2. 캠페인별 시작월, 종료월 및 총 개월 수 산출
                SELECT 
                    CMPGN_CD, 
                    UPPER_CMPGN_CD,
                    MKTG_CHANNEL,
                    MIN_YM,
                    MAX_YM,
                    TO_DATE(MIN_YM, 'YYYYMM') AS START_DATE,
                    MONTHS_BETWEEN(TO_DATE(MAX_YM, 'YYYYMM'), TO_DATE(MIN_YM, 'YYYYMM'))::INT + 1 AS TOTAL_MONTHS
                FROM (
                    -- 1. 원본에서 캠페인별 최솟값/최댓값 추출
                    SELECT 
                        CMPGN_CD, 
                        MAX(UPPER_CMPGN_CD) as UPPER_CMPGN_CD,
                        MAX(MKTG_CHANNEL) as MKTG_CHANNEL,
                        SUBSTR(MIN(FIRST_OCCRRNC_DE), 1, 6) AS MIN_YM,
                        SUBSTR(MAX(LAST_OCCRRNC_DE), 1, 6)  AS MAX_YM
                    -- FROM GN_DW.ML.DVLP_AMT_SNAPSHOT
                    FROM GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT
                    -- WHERE STDR_MT = '202606'
                      -- AND FIRST_OCCRRNC_DE >= '20100101'
                    GROUP BY CMPGN_CD
                ) BASE
            ) P
            JOIN (
                -- 연속 숫자 생성 (최대 240개월까지 지원)
                SELECT (ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1) AS SEQ
                FROM TABLE(GENERATOR(ROWCOUNT => 240))
            ) G 
              ON G.SEQ < P.TOTAL_MONTHS
        ) M
        -- LEFT JOIN GN_DW.ML.DVLP_AMT_SNAPSHOT S
        LEFT JOIN GN_DW.ML.MONTHLY_SPNSR_DVLP_AMT S
                ON S.STDR_MT = M.YYYYMM
              AND S.CMPGN_CD = M.CMPGN_CD
              AND S.FIRST_OCCRRNC_DE >= '20100101'
              -- 해당 월에 걸쳐 있는(유지 중인) 전체 데이터 연결
              --AND M.YYYYMM BETWEEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) AND SUBSTR(S.LAST_OCCRRNC_DE, 1, 6)
              AND M.YYYYMM BETWEEN SUBSTR(S.FIRST_OCCRRNC_DE, 1, 6) 
                               AND CASE 
                                       WHEN S.CANCL_RDCAMT_RSN_CD IS NOT NULL THEN SUBSTR(S.LAST_OCCRRNC_DE, 1, 6)
                                       ELSE :V_STDR_MT -- 중단이 아닌 경우 스냅샷 기준월까지 유지
                                   END
        GROUP BY 
            M.CMPGN_CD,
            M.UPPER_CMPGN_CD,
            M.MKTG_CHANNEL,
            M.YYYYMM;
        
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

