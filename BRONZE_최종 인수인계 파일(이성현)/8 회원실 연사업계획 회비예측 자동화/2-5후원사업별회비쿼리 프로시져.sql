-- 회원실 외비예측 백데이터. 파라미터 해당월 회비 실측치 삭제 후 재인입 프로시져. 
-- GNI_OP>내 리포트>01. 회비예측(월마감)>5. 신규기존 및 후원사업별 회비 레포트 스노우플레이크 이식
-- 기준년월을 입력받아 해당 연도의 회원 회비 납입 및 활동회원 데이터를 기반으로 신규·기존 회원과 본부·지부별 회비 실적을 집계하여 MM_SPNSR_CLS_AGGR_DATA에 적재한다.
-- 기준년월(YYYYMM)을 입력받아 유효성 및 미래 년월 여부를 검증하고, 해당 월의 기존 회비 집계 데이터(AGGR_TY_NM='회비')를 삭제 후 재산출한다.
-- 기준연도 1월부터 기준월까지의 월별 데이터를 생성하고, 월별 최신 결제정보 및 활동 중인 회원·후원 이력을 기준으로 활동회원 수와 회비 납입금액을 산출한다.
-- 회원 및 후원사업의 최초 등록연도를 기준으로 신규·기존 회원을 구분하고, 실적부서 계층을 기준으로 신규 회원의 본부·지부를 구분한다.
-- 회비 납입정보를 회비구분, 결제수단, 후원사업, 법인구분 및 실제 청구부서 기준으로 분류하여 기준월 납입금액과 기준연도 누계 납입금액을 집계한다.
-- 후원사업명을 기준으로 일부 사업을 국내(사단) 그룹으로 통합하고, 최종 결과는 지정된 회비 대상 후원사업 그룹을 기준으로 산출한다.
-- 후원사업별로 신규/본부, 신규/지부, 기존/기존의 3개 조합을 항상 생성하며, 실적이 없는 조합은 0으로 처리한다.
-- 기준월 납입금액은 VALUE1, 기준연도 1월부터 기준월까지의 누계 납입금액은 VALUE2에 저장하고, 집계 유형은 회비, 결과는 MM_SPNSR_CLS_AGGR_DATA에 적재한다.

CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_INSERT_MM_SPNSR_CLS_AGGR_DATA5(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    STDR_MT VARCHAR;
    CPR_DIV_CD VARCHAR;
    AGGR_TY_NM VARCHAR;
BEGIN
    -- 0. 파라미터
    IF (NOT REGEXP_LIKE(input_yyyymm, '^[0-9]{6}$')) THEN
        RETURN 'ERROR: input_yyyymm은 YYYYMM 형식이어야 합니다. 입력값=['
               || input_yyyymm || ']';
    END IF;
    IF (TRY_TO_DATE(input_yyyymm || '01', 'YYYYMMDD') IS NULL) THEN
        RETURN 'ERROR: 유효하지 않은 년월입니다. 입력값=['
               || input_yyyymm || ']';
    END IF;
    IF (
        TRY_TO_DATE(input_yyyymm || '01', 'YYYYMMDD')
        > DATE_TRUNC('MONTH', CURRENT_DATE())
    ) THEN
        RETURN 'ERROR: 미래 년월은 입력할 수 없습니다. 입력값=['
               || input_yyyymm || ']';
    END IF;
    STDR_MT := input_yyyymm;
    CPR_DIV_CD := 'I';
    AGGR_TY_NM := '회비';
    /* ============================================================
       1. 전체 데이터 구성
    ============================================================ */
    DELETE
    FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WHERE STDR_MT = :STDR_MT
    AND AGGR_TY_NM = :AGGR_TY_NM;
    INSERT INTO GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WITH
    /* ------------------------------------------------------------
       실행 파라미터
    ------------------------------------------------------------ */
    PARAMS AS
    (
        SELECT
            :STDR_MT AS STDR_MT,
            :CPR_DIV_CD AS CPR_DIV_CD,
    
            TO_DATE(:STDR_MT || '01', 'YYYYMMDD') AS STDR_MONTH_START,
    
            LAST_DAY(
                TO_DATE(:STDR_MT || '01', 'YYYYMMDD')
            ) AS STDR_MONTH_END
    ),
    /* ------------------------------------------------------------
       기준연도 1월 ~ 기준월
       MSSQL WHILE 대체
    ------------------------------------------------------------ */
    MONTHS AS
    (
        SELECT
            TO_CHAR(
                DATEADD(
                    MONTH,
                    SEQ4(),
                    DATE_TRUNC('YEAR', P.STDR_MONTH_START)
                ),
                'YYYYMM'
            ) AS RUN_MT,
    
            DATEADD(
                MONTH,
                SEQ4(),
                DATE_TRUNC('YEAR', P.STDR_MONTH_START)
            ) AS RUN_MONTH_START,
    
            LAST_DAY(
                DATEADD(
                    MONTH,
                    SEQ4(),
                    DATE_TRUNC('YEAR', P.STDR_MONTH_START)
                )
            ) AS RUN_MONTH_END,
    
            DATEADD(
                DAY,
                1,
                DATEADD(
                    MONTH,
                    1,
                    DATEADD(
                        MONTH,
                        SEQ4(),
                        DATE_TRUNC('YEAR', P.STDR_MONTH_START)
                    )
                )
            ) AS RUN_SETLE_CUTOFF
    
        FROM PARAMS P,
             TABLE(GENERATOR(ROWCOUNT => 12))
    
        WHERE SEQ4() <= MONTH(P.STDR_MONTH_START) - 1
    ),
    
    /* ============================================================
       2. 차원
    ============================================================ */
    
    
    /* ------------------------------------------------------------
       2-1. 부서 매핑
       #DEPT_MAP
    ------------------------------------------------------------ */
    DEPT_MAP AS
    (
        SELECT
            E.DEPT_ID AS SRC_DEPT_ID,
            D.DEPT_ID AS DEPT2_ID,
            C.DEPT_ID AS DEPT3_ID,
            B.DEPT_ID AS DEPT4_ID
    
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
    
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B
          ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
    
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
          ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
    
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D
          ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
    
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO E
          ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
    
        WHERE A.UPPER_DEPT_ID = 'ZV000000'
          AND C.DEPT_ID <> 'ZC000029'
    
        UNION ALL
    
        SELECT
            'Z~',
            'Z~',
            'Z~',
            'Z~'
    ),
    
    
    /* ------------------------------------------------------------
       2-2. DEPT4
       #DEPT4_DIM
    ------------------------------------------------------------ */
    DEPT4_DIM AS
    (
        SELECT
            B.DEPT_ID AS DEPT4_ID,
            B.DEPT_NM AS DEPT4_NM,
            B.SORT_ORDR
    
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
    
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B
          ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
    
        WHERE A.UPPER_DEPT_ID = 'ZV000000'
          AND A.USE_YN = 'Y'
    
        UNION ALL
    
        SELECT
            'Z~',
            '없음',
            999
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
            JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B
              ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
            WHERE A.UPPER_DEPT_ID = 'ZV000000'
              AND A.USE_YN = 'Y'
              AND B.DEPT_ID = 'Z~'
        )
    ),
    
    
    /* ------------------------------------------------------------
       2-3. 법인구분
       #CPR_DIM
    ------------------------------------------------------------ */
    CPR_DIM AS
    (
        SELECT DISTINCT
            D.DTL_CD_ID AS CPR_DIV_CD,
            D.DTL_CD_NM AS CPR_DIV_NM,
            D.SORT_ORDR
    
        FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD D
    
        WHERE D.CD_ID = 'CM019'
    ),
    
    
    /* ------------------------------------------------------------
       2-4. 후원사업
       #BUSINESS_DIM
    ------------------------------------------------------------ */
    BUSINESS_DIM AS
    (
        SELECT
            S.SPNSR_BSNS_ID,
            S.SPNSR_BSNS_NM,
            S.SPNSR_BSNS_ABRV_CD,
            S.SORT_ORDR,
    
            CASE
                WHEN S.CPR_DIV_CD = '1' THEN 'I'
                WHEN S.CPR_DIV_CD = '2' THEN 'S'
                ELSE S.CPR_DIV_CD
            END AS CPR_DIV_CD
    
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO S
    
        UNION ALL
    
        SELECT
            '99',
            '없음',
            '99',
            999,
            'Z'
    
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
            WHERE SPNSR_BSNS_ID = '99'
        )
    ),
    
    
    /* ------------------------------------------------------------
       2-5. 회비구분
       #FEE_DIM
    ------------------------------------------------------------ */
    FEE_DIM AS
    (
        SELECT DISTINCT
            D.DTL_CD_ID AS MBRFEE_DIV_CD,
            D.DTL_CD_NM AS MBRFEE_DIV_NM,
            D.SORT_ORDR
    
        FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD D
    
        WHERE D.CD_ID = 'PM010'
    ),
    
    
    /* ============================================================
       3. 월별 최신 결제정보
       #RUN_SETLE_MONTH
    ============================================================ */
    
    SETLE_SOURCE AS
    (
        SELECT
            M.RUN_MT,
            C.SETLE_KEY,
            C.MBER_NO,
            C.CPR_DIV_CD,
            C.SETLE_CD,
            C.FRST_REGIST_DT
    
        FROM MONTHS M
    
        JOIN GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO C
          ON C.FRST_REGIST_DT <= M.RUN_SETLE_CUTOFF
    
        UNION ALL
    
        SELECT
            M.RUN_MT,
            H.SETLE_KEY,
            H.MBER_NO,
            H.CPR_DIV_CD,
            H.SETLE_CD,
            H.REGIST_DT AS FRST_REGIST_DT
    
        FROM MONTHS M
    
        JOIN GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST H
          ON H.REGIST_DT <= M.RUN_SETLE_CUTOFF
    ),
    
    
    SETLE_RANKED AS
    (
        SELECT
            RUN_MT,
            MBER_NO,
    
            CASE
                WHEN CPR_DIV_CD = '1' THEN 'I'
                WHEN CPR_DIV_CD = '2' THEN 'S'
                ELSE CPR_DIV_CD
            END AS CPR_DIV_CD,
    
            SETLE_CD,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    RUN_MT,
                    MBER_NO,
                    CASE
                        WHEN CPR_DIV_CD = '1' THEN 'I'
                        WHEN CPR_DIV_CD = '2' THEN 'S'
                        ELSE CPR_DIV_CD
                    END
    
                ORDER BY SETLE_KEY DESC
            ) AS RNUM
    
        FROM SETLE_SOURCE
    ),
    RUN_SETLE_MONTH AS
    (
        SELECT
            RUN_MT,
            MBER_NO,
            CPR_DIV_CD,
            COALESCE(SETLE_CD, '4') AS SETLE_CD
    
        FROM SETLE_RANKED
    
        WHERE RNUM = 1
    ),
    
    
    /* ============================================================
       4. 월별 활동회원
    ============================================================ */
    
    
    /* ------------------------------------------------------------
       4-1. 마지막 중단일
    ------------------------------------------------------------ */
    LAST_DSCNTC AS
    (
        SELECT
            M.RUN_MT,
            D.MBER_NO,
            D.SPNSR_DSCNTC_DE,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    M.RUN_MT,
                    D.MBER_NO
    
                ORDER BY D.SPNSR_DSCNTC_DE DESC
            ) AS RNUM
    
        FROM MONTHS M
        
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC D
          ON D.SPNSR_DSCNTC_DE <=
             TO_CHAR(M.RUN_MONTH_END, 'YYYYMMDD')
    ),
    
    
    /* ------------------------------------------------------------
       4-2. 마지막 재후원일
    ------------------------------------------------------------ */
    LAST_RE_SPNSR AS
    (
        SELECT
            M.RUN_MT,
            R.MBER_NO,
            R.RE_SPNSR_DE,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    M.RUN_MT,
                    R.MBER_NO
    
                ORDER BY R.RE_SPNSR_DE DESC
            ) AS RNUM
    
        FROM MONTHS M
        
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR R
          ON R.RE_SPNSR_DE <=
             TO_CHAR(M.RUN_MONTH_END, 'YYYYMMDD')
    ),
    
    
    /* ------------------------------------------------------------
       4-3. 실제 활동 종료일
    ------------------------------------------------------------ */
    LAST_ACTIVITY_DATE AS
    (
        SELECT
            D.RUN_MT,
            D.MBER_NO,
    
            CASE
    
                WHEN R.RE_SPNSR_DE IS NULL
                    THEN DATEADD(
                        DAY,
                        -1,
                        TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD')
                    )
    
                WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE
                    THEN DATEADD(
                        DAY,
                        -1,
                        TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD')
                    )
    
                WHEN R.RE_SPNSR_DE <
                     TO_CHAR(
                         M.RUN_MONTH_END,
                         'YYYYMMDD'
                     )
                    THEN M.RUN_MONTH_END
    
                ELSE TO_DATE(
                    R.RE_SPNSR_DE,
                    'YYYYMMDD'
                )
    
            END AS ACTUAL_DT
    
        FROM LAST_DSCNTC D
    
        JOIN MONTHS M
          ON D.RUN_MT = M.RUN_MT
    
        LEFT JOIN LAST_RE_SPNSR R
          ON D.RUN_MT = R.RUN_MT
         AND D.MBER_NO = R.MBER_NO
         AND R.RNUM = 1
    
        WHERE D.RNUM = 1
    ),
    
    
    /* ------------------------------------------------------------
       4-4. 활동 중인 후원 존재 여부
    ------------------------------------------------------------ */
    HAS_LIVE_SPONSOR AS
    (
        SELECT DISTINCT
            M.RUN_MT,
            S.MBER_NO
    
        FROM MONTHS M
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
          ON TO_DATE(
                 TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD'),
                 'YYYYMMDD'
             )
             <= M.RUN_MONTH_END
        
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
          ON S.SPNSR_NO = B.SPNSR_NO
    
        WHERE COALESCE(
                  B.SPNSR_DSCNTC_DE,
                  '99991231'
              ) >
              TO_CHAR(
                  M.RUN_MONTH_END,
                  'YYYYMMDD'
              )
    ),
    
    
    /* ------------------------------------------------------------
       4-5. 실행월 활동회원
       #RUN_ACTIVE_MEMBER
    ------------------------------------------------------------ */
    RUN_ACTIVE_MEMBER AS
    (
        SELECT DISTINCT
            RM.RUN_MT,
            M.MBER_NO
    
        FROM MONTHS RM
    
        JOIN HAS_LIVE_SPONSOR L
          ON RM.RUN_MT = L.RUN_MT
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
          ON L.MBER_NO = M.MBER_NO
    
        LEFT JOIN LAST_ACTIVITY_DATE A
          ON RM.RUN_MT = A.RUN_MT
         AND M.MBER_NO = A.MBER_NO
    
        WHERE RM.RUN_MONTH_END
              BETWEEN TO_DATE(M.FRST_REGIST_DT)
                  AND COALESCE(
                        A.ACTUAL_DT,
                        TO_DATE('9999-12-31')
                      )
    ),
    /* ============================================================
       5. 월별 활동행 재현
    ============================================================ */
    
    ACTIVE_HISTORY AS
    (
        SELECT
            M.RUN_MT,
    
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.OCCRRNC_DE,
            A.SER_NO,
            A.MBER_NO,
            A.SPNSR_BSNS_ID,
    
            SUM(
                TO_DECIMAL(
                    A.SPNSR_AMT,
                    38,
                    4
                )
            ) OVER
            (
                PARTITION BY
                    M.RUN_MT,
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
            ) AS SUM_AMT,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    M.RUN_MT,
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
    
                ORDER BY
                    A.OCCRRNC_DE DESC,
                    A.SER_NO DESC
            ) AS RNUM
    
        FROM MONTHS M
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
          ON A.OCCRRNC_DE <=
             TO_CHAR(
                 M.RUN_MONTH_END,
                 'YYYYMMDD'
             )
    ),
    
    
    RUN_ACTIVE_DETAIL AS
    (
        SELECT
            A.RUN_MT AS STRD_MT,
    
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.MBER_NO,
    
            CASE
                WHEN TO_CHAR(M.FRST_REGIST_DT, 'YYYY') =
                     LEFT(A.RUN_MT, 4)
    
                 AND TO_CHAR(S.FRST_REGIST_DT, 'YYYY') =
                     LEFT(A.RUN_MT, 4)
    
                    THEN '1'
    
                ELSE '2'
    
            END AS NEW_OLD_DIV_CD,
    
            COALESCE(
                S.ACMSLT_DEPT_CD,
                'Z~'
            ) AS ACMSLT_DEPT_CD,
    
            COALESCE(
                MAP.DEPT2_ID,
                'Z~'
            ) AS ACMSLT_DEPT2_CD,
    
            COALESCE(
                MAP.DEPT3_ID,
                'Z~'
            ) AS ACMSLT_DEPT3_CD,
    
            COALESCE(
                MAP.DEPT4_ID,
                'Z~'
            ) AS ACMSLT_DEPT4_CD,
    
            COALESCE(
                A.SPNSR_BSNS_ID,
                '99'
            ) AS SPNSR_BSNS_ID,
    
            COALESCE(
                ST.CPR_DIV_CD,
                'I'
            ) AS CPR_DIV_CD,
    
            COALESCE(
                ST.SETLE_CD,
                '4'
            ) AS SETLE_CD
    
        FROM ACTIVE_HISTORY A
    
        JOIN RUN_ACTIVE_MEMBER AM
          ON A.RUN_MT = AM.RUN_MT
         AND A.MBER_NO = AM.MBER_NO
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
          ON A.MBER_NO = M.MBER_NO
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
          ON A.SPNSR_NO = S.SPNSR_NO
         AND A.MBER_NO = S.MBER_NO
    
        LEFT JOIN BUSINESS_DIM B
          ON A.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
    
        LEFT JOIN RUN_SETLE_MONTH ST
          ON A.RUN_MT = ST.RUN_MT
         AND A.MBER_NO = ST.MBER_NO
         AND B.CPR_DIV_CD = ST.CPR_DIV_CD
    
        LEFT JOIN DEPT_MAP MAP
          ON COALESCE(
                 S.ACMSLT_DEPT_CD,
                 'Z~'
             ) = MAP.SRC_DEPT_ID
    
        WHERE A.RNUM = 1
          AND A.SUM_AMT > 0
    ), 
    
    
    
    /* ------------------------------------------------------------
       원 적재 Grain → 회원 집계
    ------------------------------------------------------------ */
    ACTIVITY_PROC_GRAIN AS
    (
        SELECT
            D.STRD_MT,
            D.CPR_DIV_CD,
            D.NEW_OLD_DIV_CD,
            D.ACMSLT_DEPT_CD,
            D.ACMSLT_DEPT2_CD,
            D.ACMSLT_DEPT3_CD,
            D.ACMSLT_DEPT4_CD,
            D.SPNSR_BSNS_ID,
            D.SETLE_CD,
    
            COUNT(
                DISTINCT D.MBER_NO
            ) AS ACT_MBR_CNT
    
        FROM RUN_ACTIVE_DETAIL D
    
        GROUP BY
            D.STRD_MT,
            D.CPR_DIV_CD,
            D.NEW_OLD_DIV_CD,
            D.ACMSLT_DEPT_CD,
            D.ACMSLT_DEPT2_CD,
            D.ACMSLT_DEPT3_CD,
            D.ACMSLT_DEPT4_CD,
            D.SPNSR_BSNS_ID,
            D.SETLE_CD
    ),
    
    
    /* ============================================================
       6. 활동회원 Fact
    ============================================================ */
    
    ACTIVITY_FACT AS
    (
        SELECT
            G.STRD_MT AS SOURCE_MT,
    
            'E' AS MBRFEE_DIV_CD,
    
            COALESCE(
                G.NEW_OLD_DIV_CD,
                '2'
            ) AS NEW_OLD_DIV_CD,
    
            COALESCE(
                G.ACMSLT_DEPT4_CD,
                'Z~'
            ) AS DEPT4_ID,
    
            COALESCE(
                G.SPNSR_BSNS_ID,
                '99'
            ) AS SPNSR_BSNS_ID,
    
            COALESCE(
                G.CPR_DIV_CD,
                'Z'
            ) AS CPR_DIV_CD,
    
            SUM(
                G.ACT_MBR_CNT
            ) AS ACT_MBR_CNT,
    
            TO_DECIMAL(
                0,
                38,
                0
            ) AS PAY_AMT
    
        FROM ACTIVITY_PROC_GRAIN G
    
        CROSS JOIN PARAMS P
    
        WHERE P.CPR_DIV_CD IS NULL
           OR COALESCE(
                  G.CPR_DIV_CD,
                  'Z'
              ) = P.CPR_DIV_CD
    
        GROUP BY
            G.STRD_MT,
            COALESCE(G.NEW_OLD_DIV_CD, '2'),
            COALESCE(G.ACMSLT_DEPT4_CD, 'Z~'),
            COALESCE(G.SPNSR_BSNS_ID, '99'),
            COALESCE(G.CPR_DIV_CD, 'Z')
    ),
    
    /* ============================================================
       7. 활동회원의 신규/기존 구분
    ============================================================ */
    
    RUN_ACTIVE_NEW_OLD AS
    (
        SELECT DISTINCT
            D.STRD_MT,
            D.MBER_NO,
            D.NEW_OLD_DIV_CD
    
        FROM RUN_ACTIVE_DETAIL D
    ),
    
    
    /* ============================================================
       8. 납입정보 재현
    ============================================================ */
    
    
    /* ------------------------------------------------------------
       8-1. 후원사업 정보
    ------------------------------------------------------------ */
    SPNSR_BSNS_SOURCE AS
    (
        SELECT
            S.SPNSR_NO,
            B.SPNSR_BSNS_NO,
            S.ACMSLT_DEPT_CD
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
          ON S.SPNSR_NO = B.SPNSR_NO
    ),
    
    
    /* ------------------------------------------------------------
       8-2. 계좌 정보
       MSSQL TOP(1) 대체
    ------------------------------------------------------------ */
    INSTT_ACNUT_BASE AS
    (
        SELECT
            A.ACNUT_SER_NO,
            A.CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT A
    ),
    INSTT_ACNUT_SOURCE AS
    (
        SELECT
            ACNUT_SER_NO,
            CHRG_DEPT_CD
        FROM INSTT_ACNUT_BASE
    
        UNION ALL
    
        SELECT
            '9999' AS ACNUT_SER_NO,
            'Z~' AS CHRG_DEPT_CD
        FROM INSTT_ACNUT_BASE
        QUALIFY ROW_NUMBER() OVER (ORDER BY ACNUT_SER_NO) = 1
    ),
    /* ------------------------------------------------------------
       8-3. 납입 원천
    ------------------------------------------------------------ */
    PAY_SOURCE AS
    (
        SELECT
            P.MBER_NO,
    
            COALESCE(
                P.SPNSR_BSNS_ID,
                '99'
            ) AS SPNSR_BSNS_ID,
    
            COALESCE(
                P.CPR_DIV_CD,
                'Z'
            ) AS CPR_DIV_CD,
    
            COALESCE(
                P.MBRFEE_DIV_CD,
                'Z'
            ) AS MBRFEE_DIV_CD,
    
            CASE
                WHEN P.SETLE_CD IN
                     ('3', '6', '10', '13')
                    THEN '10'
    
                ELSE COALESCE(
                    P.SETLE_CD,
                    '999'
                )
            END AS SETLE_CD,
    
            COALESCE(
                S.ACMSLT_DEPT_CD,
                'Z~'
            ) AS SPNSR_ACMSLT_DEPT_CD,
    
            IA4.CHRG_DEPT_CD AS INSTT_CHRG_DEPT_CD,
    
            IA10.CHRG_DEPT_CD AS CMPNY_CHRG_DEPT_CD,
    
            TO_DECIMAL(
                P.PAY_AMT,
                38,
                0
            ) AS PAY_AMT,
    
            TO_CHAR(
                P.PAY_DE,
                'YYYYMM'
            ) AS RUN_MT
    
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
        LEFT JOIN SPNSR_BSNS_SOURCE S
          ON P.SPNSR_NO = S.SPNSR_NO
         AND P.SPNSR_BSNS_NO = S.SPNSR_BSNS_NO
    
        LEFT JOIN INSTT_ACNUT_SOURCE IA4
          ON P.ACNUT_SER_NO = IA4.ACNUT_SER_NO
    
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT CA
          ON P.SETLE_CMPNY_ACNT_NO =
             CA.SETLE_CMPNY_ACNT_NO
    
        LEFT JOIN INSTT_ACNUT_SOURCE IA10
          ON CA.ACNUT_SER_NO =
             IA10.ACNUT_SER_NO
        WHERE P.USE_YN = 'Y'
          AND P.PRCS_STAT_CD = 'S'
          AND P.PAY_STAT_CD = 'S'
          AND P.RETUN_REQUST_KEY IS NULL
    
          AND EXISTS
          (
              SELECT 1
              FROM MONTHS M
              WHERE P.PAY_DE >= M.RUN_MONTH_START
                AND P.PAY_DE <
                    DATEADD(
                        DAY,
                        1,
                        M.RUN_MONTH_END
                    )
                AND
                (
                    :CPR_DIV_CD IS NULL
                    OR COALESCE(
                           P.CPR_DIV_CD,
                           'Z'
                       ) = :CPR_DIV_CD
                )
          )
    ),
    
    /* ------------------------------------------------------------
       8-4. 실제 청구 부서
    ------------------------------------------------------------ */
    PAY_CHARGE AS
    (
        SELECT
            P.*,
    
            CASE
                WHEN P.SETLE_CD = '4'
                    THEN P.INSTT_CHRG_DEPT_CD
    
                WHEN P.SETLE_CD IN
                     ('3', '6', '10', '13')
                    THEN P.CMPNY_CHRG_DEPT_CD
    
                ELSE 'D000011'
            END AS CHRG_DEPT_CD
    
        FROM PAY_SOURCE P
    ),
    
    
    /* ------------------------------------------------------------
       8-5. 납입 최종 대상
    ------------------------------------------------------------ */
    PAY_FN AS
    (
        SELECT
            P.RUN_MT,
            P.MBER_NO,
            P.SPNSR_BSNS_ID,
            P.CPR_DIV_CD,
            P.MBRFEE_DIV_CD,
    
            CASE
    
                WHEN P.MBRFEE_DIV_CD = 'E'
                    THEN P.SPNSR_ACMSLT_DEPT_CD
    
                WHEN P.MBRFEE_DIV_CD IN ('I', 'U')
                    THEN P.CHRG_DEPT_CD
    
                WHEN P.MBRFEE_DIV_CD = 'G'
                    THEN 'D000011'
    
                ELSE NULL
    
            END AS ACMSLT_DEPT_CD,
    
            P.PAY_AMT
    
        FROM PAY_CHARGE P
    
        WHERE P.CHRG_DEPT_CD = 'D000011'
    ),
    
    
    /* ============================================================
       9. 납입 Fact
    ============================================================ */
    
    PAYMENT_FACT AS
    (
        SELECT
            P.RUN_MT AS SOURCE_MT,
    
            P.MBRFEE_DIV_CD,
    
            COALESCE(
                N.NEW_OLD_DIV_CD,
                '2'
            ) AS NEW_OLD_DIV_CD,
    
            COALESCE(
                MAP.DEPT4_ID,
                'Z~'
            ) AS DEPT4_ID,
    
            COALESCE(
                P.SPNSR_BSNS_ID,
                '99'
            ) AS SPNSR_BSNS_ID,
    
            COALESCE(
                P.CPR_DIV_CD,
                'Z'
            ) AS CPR_DIV_CD,
    
            TO_NUMBER(0) AS ACT_MBR_CNT,
    
            SUM(
                P.PAY_AMT
            ) AS PAY_AMT
    
        FROM PAY_FN P
    
        LEFT JOIN RUN_ACTIVE_NEW_OLD N
          ON P.RUN_MT = N.STRD_MT
         AND P.MBER_NO = N.MBER_NO
    
        LEFT JOIN DEPT_MAP MAP
          ON COALESCE(
                 P.ACMSLT_DEPT_CD,
                 'Z~'
             ) = MAP.SRC_DEPT_ID
    
        GROUP BY
            P.RUN_MT,
            P.MBRFEE_DIV_CD,
            COALESCE(N.NEW_OLD_DIV_CD, '2'),
            COALESCE(MAP.DEPT4_ID, 'Z~'),
            COALESCE(P.SPNSR_BSNS_ID, '99'),
            COALESCE(P.CPR_DIV_CD, 'Z')
    ),
    
    /* ============================================================
       10. 월별 Fact
       #MONTHLY_FACT 대체
    ============================================================ */
    
    MONTHLY_FACT AS
    (
        SELECT
            SOURCE_MT,
            MBRFEE_DIV_CD,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            SPNSR_BSNS_ID,
            CPR_DIV_CD,
            ACT_MBR_CNT,
            PAY_AMT
    
        FROM ACTIVITY_FACT
    
        UNION ALL
    
        SELECT
            SOURCE_MT,
            MBRFEE_DIV_CD,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            SPNSR_BSNS_ID,
            CPR_DIV_CD,
            ACT_MBR_CNT,
            PAY_AMT
    
        FROM PAYMENT_FACT
    ),
    /* ============================================================
       11. 기준월 결과
       #CURRENT_FACT 대체
    ============================================================ */
    
    CURRENT_FACT AS
    (
        SELECT
            P.STDR_MT AS STRD_MT,
    
            F.MBRFEE_DIV_CD,
            F.NEW_OLD_DIV_CD,
            F.DEPT4_ID,
            F.SPNSR_BSNS_ID,
            F.CPR_DIV_CD,
    
            SUM(
                F.ACT_MBR_CNT
            ) AS WJXBFS1,
    
            SUM(
                F.PAY_AMT
            ) AS WJXBFS2
    
        FROM MONTHLY_FACT F
    
        CROSS JOIN PARAMS P
    
        WHERE F.SOURCE_MT = P.STDR_MT
    
        GROUP BY
            P.STDR_MT,
            F.MBRFEE_DIV_CD,
            F.NEW_OLD_DIV_CD,
            F.DEPT4_ID,
            F.SPNSR_BSNS_ID,
            F.CPR_DIV_CD
    ),
    
    
    /* ============================================================
       12. YTD
       #YTD_FACT 대체
    ============================================================ */
    
    YTD_FACT AS
    (
        SELECT
            P.STDR_MT AS STRD_MT,
    
            F.MBRFEE_DIV_CD,
            F.NEW_OLD_DIV_CD,
            F.DEPT4_ID,
            F.SPNSR_BSNS_ID,
            F.CPR_DIV_CD,
    
            SUM(
                F.PAY_AMT
            ) AS WJXBFS3
    
        FROM MONTHLY_FACT F
    
        CROSS JOIN PARAMS P
    
        GROUP BY
            P.STDR_MT,
            F.MBRFEE_DIV_CD,
            F.NEW_OLD_DIV_CD,
            F.DEPT4_ID,
            F.SPNSR_BSNS_ID,
            F.CPR_DIV_CD
    ),
    /* ============================================================
       13. 출력 기준 행 생성
       - STRD_MT
       - CPR_DIV_NM
       - SPNSR_BSNS_NM
       별로 신규본부 / 신규지부 / 기존 행을 항상 보장
    ============================================================ */
    /* ============================================================
       13. 출력 기준 행 생성
       - STRD_MT
       - CPR_DIV_NM
       - SPNSR_BSNS_NM
       별로 신규/본부
            신규/지부
            기존/기존
       3개 행을 항상 보장
    ============================================================ */
    RESULT_BASE AS
    (
        SELECT
            P.STDR_MT AS STRD_MT,
            CP.CPR_DIV_CD,
            CP.CPR_DIV_NM,
    
            CASE
                WHEN COALESCE(B.SPNSR_BSNS_NM, '없음') IN
                (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                THEN '국내(사단)'
    
                ELSE COALESCE(
                    B.SPNSR_BSNS_NM,
                    '없음'
                )
            END AS SPNSR_BSNS_GRP_NM,
    
            X.NEW_EXST_DIV_NM,
            X.HDQ_BRNCH_GRP_NM
    
        FROM PARAMS P
    
        CROSS JOIN CPR_DIM CP
    
        JOIN BUSINESS_DIM B
          ON B.CPR_DIV_CD = CP.CPR_DIV_CD
    
        CROSS JOIN
        (
            SELECT
                '신규' AS NEW_EXST_DIV_NM,
                '본부' AS HDQ_BRNCH_GRP_NM
    
            UNION ALL
    
            SELECT
                '신규',
                '지부'
    
            UNION ALL
    
            SELECT
                '기존',
                '기존'
        ) X
    
        WHERE P.CPR_DIV_CD IS NULL
           OR CP.CPR_DIV_CD = P.CPR_DIV_CD
    
        GROUP BY
            P.STDR_MT,
            CP.CPR_DIV_CD,
            CP.CPR_DIV_NM,
    
            CASE
                WHEN COALESCE(B.SPNSR_BSNS_NM, '없음') IN
                (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                THEN '국내(사단)'
    
                ELSE COALESCE(
                    B.SPNSR_BSNS_NM,
                    '없음'
                )
            END,
    
            X.NEW_EXST_DIV_NM,
            X.HDQ_BRNCH_GRP_NM
    ),
    
    /* ============================================================
       14. 실제 집계 결과
    ============================================================ */
    RESULT_AGGR AS
    (
        SELECT
            STRD_MT,
            CPR_DIV_CD,
            CPR_DIV_NM,
            SPNSR_BSNS_GRP_NM,
            NEW_EXST_DIV_NM,
            HDQ_BRNCH_GRP_NM,
    
            SUM(VALUE1) AS VALUE1,
            SUM(VALUE2) AS VALUE2
    
        FROM
        (
            /* ====================================================
               기준월 납입금액
            ==================================================== */
            SELECT
                C.STRD_MT,
                C.CPR_DIV_CD,
                CP.CPR_DIV_NM,
    
                CASE
                    WHEN COALESCE(B.SPNSR_BSNS_NM, '없음') IN
                    (
                        '결식아동지원',
                        '국내아동권리보호사업(사단법인)',
                        '복지관후원',
                        '아동복지시설지원',
                        '아동학대예방',
                        '저소득가정지원'
                    )
                    THEN '국내(사단)'
    
                    ELSE COALESCE(
                        B.SPNSR_BSNS_NM,
                        '없음'
                    )
                END AS SPNSR_BSNS_GRP_NM,
    
                CASE
                    WHEN C.NEW_OLD_DIV_CD = '1'
                        THEN '신규'
                    ELSE '기존'
                END AS NEW_EXST_DIV_NM,
    
                CASE
                    WHEN C.NEW_OLD_DIV_CD = '1'
                     AND COALESCE(
                            D4.DEPT4_NM,
                            '없음'
                         ) IN (
                            '본부',
                            '본부(사복)'
                         )
                        THEN '본부'
    
                    WHEN C.NEW_OLD_DIV_CD = '1'
                        THEN '지부'
    
                    WHEN COALESCE(
                            D4.DEPT4_NM,
                            '없음'
                         ) = '없음'
                        THEN '본부'
    
                    ELSE '기존'
                END AS HDQ_BRNCH_GRP_NM,
    
                C.WJXBFS2 AS VALUE1,
    
                TO_DECIMAL(
                    0,
                    38,
                    0
                ) AS VALUE2
    
            FROM CURRENT_FACT C
    
            LEFT JOIN CPR_DIM CP
              ON C.CPR_DIV_CD = CP.CPR_DIV_CD
    
            LEFT JOIN BUSINESS_DIM B
              ON C.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
    
            LEFT JOIN DEPT4_DIM D4
              ON C.DEPT4_ID = D4.DEPT4_ID
    
    
            UNION ALL
    
    
            /* ====================================================
               기준연도 1월 ~ 기준월 누계 납입금액
            ==================================================== */
            SELECT
                Y.STRD_MT,
                Y.CPR_DIV_CD,
                CP.CPR_DIV_NM,
    
                CASE
                    WHEN COALESCE(B.SPNSR_BSNS_NM, '없음') IN
                    (
                        '결식아동지원',
                        '국내아동권리보호사업(사단법인)',
                        '복지관후원',
                        '아동복지시설지원',
                        '아동학대예방',
                        '저소득가정지원'
                    )
                    THEN '국내(사단)'
    
                    ELSE COALESCE(
                        B.SPNSR_BSNS_NM,
                        '없음'
                    )
                END AS SPNSR_BSNS_GRP_NM,
    
                CASE
                    WHEN Y.NEW_OLD_DIV_CD = '1'
                        THEN '신규'
                    ELSE '기존'
                END AS NEW_EXST_DIV_NM,
    
                CASE
                    WHEN Y.NEW_OLD_DIV_CD = '1'
                     AND COALESCE(
                            D4.DEPT4_NM,
                            '없음'
                         ) IN (
                            '본부',
                            '본부(사복)'
                         )
                        THEN '본부'
    
                    WHEN Y.NEW_OLD_DIV_CD = '1'
                        THEN '지부'
    
                    WHEN COALESCE(
                            D4.DEPT4_NM,
                            '없음'
                         ) = '없음'
                        THEN '본부'
    
                    ELSE '기존'
                END AS HDQ_BRNCH_GRP_NM,
    
                TO_DECIMAL(
                    0,
                    38,
                    0
                ) AS VALUE1,
    
                Y.WJXBFS3 AS VALUE2
    
            FROM YTD_FACT Y
    
            LEFT JOIN CPR_DIM CP
              ON Y.CPR_DIV_CD = CP.CPR_DIV_CD
    
            LEFT JOIN BUSINESS_DIM B
              ON Y.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
    
            LEFT JOIN DEPT4_DIM D4
              ON Y.DEPT4_ID = D4.DEPT4_ID
        ) A
    
        GROUP BY
            STRD_MT,
            CPR_DIV_CD,
            CPR_DIV_NM,
            SPNSR_BSNS_GRP_NM,
            NEW_EXST_DIV_NM,
            HDQ_BRNCH_GRP_NM
    )
    SELECT
        R.STRD_MT,
        :AGGR_TY_NM AS AGGR_TY_NM,
        R.CPR_DIV_NM,
        R.SPNSR_BSNS_GRP_NM,
        R.NEW_EXST_DIV_NM,
        R.HDQ_BRNCH_GRP_NM,
    
        COALESCE(
            A.VALUE1,
            0
        ) AS VALUE1,
    
        COALESCE(
            A.VALUE2,
            0
        ) AS VALUE2
    
    FROM RESULT_BASE R
    
    LEFT JOIN RESULT_AGGR A
      ON R.STRD_MT = A.STRD_MT
     AND R.CPR_DIV_CD = A.CPR_DIV_CD
     AND R.CPR_DIV_NM = A.CPR_DIV_NM
     AND R.SPNSR_BSNS_GRP_NM = A.SPNSR_BSNS_GRP_NM
     AND R.NEW_EXST_DIV_NM = A.NEW_EXST_DIV_NM
     AND R.HDQ_BRNCH_GRP_NM = A.HDQ_BRNCH_GRP_NM
    WHERE R.SPNSR_BSNS_GRP_NM IN (
        '국내(사단)',
        '대북지원사업',
        '보건의료지원사업',
        '식수위생지원사업',
        '재난구호지원사업',
        '전체사업지원',
        '좋은이웃',
        '해외교육지원사업',
        '해외아동결연',
        '해외지역개발사업',
        '희망학교지원사업'
    )
    ORDER BY
        R.STRD_MT,
        R.CPR_DIV_NM,
        R.SPNSR_BSNS_GRP_NM,
    
        CASE
            WHEN R.NEW_EXST_DIV_NM = '신규'
             AND R.HDQ_BRNCH_GRP_NM = '본부'
                THEN 1
    
            WHEN R.NEW_EXST_DIV_NM = '신규'
             AND R.HDQ_BRNCH_GRP_NM = '지부'
                THEN 2
    
            WHEN R.NEW_EXST_DIV_NM = '기존'
             AND R.HDQ_BRNCH_GRP_NM = '기존'
                THEN 3
    
            ELSE 9
        END;
    
    RETURN 'SUCCESS: ' || :STDR_MT;
END;
$$;



