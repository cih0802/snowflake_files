-- 회원실 외비예측 백데이터. 파라미터 해당월 감액 실측치 삭제 후 재인입 프로시져. 
-- GNI_OP>내 리포트>01. 회비예측(월마감)>3. 후원사업별 감액회원 레포트 
-- 기준년월을 입력받아 해당 연도의 후원 감액 및 기준월 활동 후원 데이터를 기반으로 신규·기존 회원과 본부·지부별 감액금액을 집계하여 MM_SPNSR_CLS_AGGR_DATA에 적재한다.
-- 기준년월(YYYYMM)을 입력받아 유효성 및 미래 년월 여부를 검증하고, 해당 월의 기존 감액 집계 데이터(AGGR_TY_NM='감액')를 삭제 후 재산출한다.
-- 해당 연도 1월부터 기준월까지의 후원 감액 이력을 조회하여 당월 및 연간 누적(YTD) 감액 실적을 산출하고, 실제 감액이 발생한 후원 건을 대상으로 집계한다.
-- 기준월 말 활동 중인 회원의 후원 이력을 기준으로 기준월 활동 회원 및 후원금액을 산출하여 감액 실적과 함께 집계한다.
-- 회원 최초등록연도와 후원 최초등록연도를 기준으로 신규·기존 회원을 구분하고, 실적부서 계층을 기준으로 신규 회원의 본부·지부를 구분한다.
-- 후원사업명을 기준으로 일부 사업을 국내(사단) 그룹으로 통합하고, 사단 법인(CPR_DIV_CD='I') 대상으로 집계한다.
-- 후원사업 그룹별로 기존/기존, 신규/본부, 신규/지부의 3개 조합을 항상 생성하며, 실적이 없는 조합은 0으로 처리한다.
-- 감액금액은 10,000원 단위로 환산하여 VALUE1에 저장하고, 집계 유형은 감액, 결과는 MM_SPNSR_CLS_AGGR_DATA에 적재한다.

CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_INSERT_MM_SPNSR_CLS_AGGR_DATA3(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    STDR_MT VARCHAR;
    FRST_MT VARCHAR;
    STDR_MT_01 VARCHAR;
    STDR_MT_31 VARCHAR;
    STDR_MT_END_DT VARCHAR;
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
    FRST_MT := LEFT(:STDR_MT, 4) || '01';
    STDR_MT_01 := :STDR_MT || '01';
    STDR_MT_31 := :STDR_MT || '31';
    STDR_MT_END_DT := TO_CHAR(
        LAST_DAY(TO_DATE(:STDR_MT || '01', 'YYYYMMDD')),
        'YYYYMMDD'
    );
    AGGR_TY_NM := '감액';
    
    DELETE
    FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WHERE STDR_MT = :STDR_MT
    AND AGGR_TY_NM = :AGGR_TY_NM;
    INSERT INTO GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WITH
    /* =========================================================
       1. 실적부서 → DEPT4
       ========================================================= */
    DEPT_MAP AS (
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
    
    /* =========================================================
       2. DEPT4 차원
       ========================================================= */
    DEPT4_DIM AS (
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
    ),
    
    /* =========================================================
       3. 법인 구분
       ========================================================= */
    CPR_DIM AS (
        SELECT DISTINCT
            D.DTL_CD_ID AS CPR_DIV_CD,
            D.DTL_CD_NM AS CPR_DIV_NM,
            D.SORT_ORDR
        FROM GN_DW.BRONZE_CRM.TC_CMMN_CD C
        JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD D
          ON C.CD_ID = D.CD_ID
        WHERE D.CD_ID = 'CM019'
    ),
    
    /* =========================================================
       4. 후원사업
       ========================================================= */
    BUSINESS_DIM AS (
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
        WHERE NOT EXISTS (
            SELECT 1
            FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
            WHERE SPNSR_BSNS_ID = '99'
        )
    ),
    
    /* =========================================================
       5. 회원
       ========================================================= */
    MEMBER_MONTH AS (
        SELECT
            M.MBER_NO,
            M.FRST_REGIST_DT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        WHERE TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM') <= :STDR_MT
    ),
    
    /* =========================================================
       6. 결제정보
       ========================================================= */
    SETLE_MONTH AS (
        SELECT
            MBER_NO,
            CPR_DIV_CD
        FROM (
            SELECT
                U.MBER_NO,
                U.CPR_DIV_CD,
                ROW_NUMBER() OVER (
                    PARTITION BY
                        U.MBER_NO,
                        U.CPR_DIV_CD
                    ORDER BY U.SETLE_KEY DESC
                ) AS RNUM
            FROM (
                SELECT
                    SETLE_KEY,
                    MBER_NO,
                    CPR_DIV_CD,
                    FRST_REGIST_DT
                FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
    
                UNION ALL
    
                SELECT
                    SETLE_KEY,
                    MBER_NO,
                    CPR_DIV_CD,
                    REGIST_DT
                FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
            ) U
            WHERE U.FRST_REGIST_DT <= DATEADD(
                DAY,
                1,
                DATEADD(
                    MONTH,
                    1,
                    TO_DATE(:STDR_MT_01, 'YYYYMMDD')
                )
            )
        )
        WHERE RNUM = 1
    ),
    
    /* =========================================================
       7. 활동회원
       ========================================================= */
    LAST_DSCNTC AS (
        SELECT
            D.MBER_NO,
            D.SPNSR_DSCNTC_DE,
            ROW_NUMBER() OVER (
                PARTITION BY D.MBER_NO
                ORDER BY D.SPNSR_DSCNTC_DE DESC
            ) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC D
        WHERE D.SPNSR_DSCNTC_DE <= :STDR_MT_31
    ),
    
    LAST_RE_SPNSR AS (
        SELECT
            R.MBER_NO,
            R.RE_SPNSR_DE,
            ROW_NUMBER() OVER (
                PARTITION BY R.MBER_NO
                ORDER BY R.RE_SPNSR_DE DESC
            ) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR R
        WHERE R.RE_SPNSR_DE <= :STDR_MT_31
    ),
    
    LAST_ACTIVITY_DATE AS (
        SELECT
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
    
                WHEN R.RE_SPNSR_DE < :STDR_MT_END_DT
                    THEN TO_DATE(:STDR_MT_END_DT, 'YYYYMMDD')
    
                ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD')
            END AS ACTUAL_DT
    
        FROM LAST_DSCNTC D
    
        LEFT JOIN LAST_RE_SPNSR R
          ON D.MBER_NO = R.MBER_NO
         AND R.RNUM = 1
    
        WHERE D.RNUM = 1
    ),
    
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT
            S.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
          ON S.SPNSR_NO = B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD') <= :STDR_MT_31
          AND COALESCE(B.SPNSR_DSCNTC_DE, '99991231') > :STDR_MT_31
    ),
    
    ACTIVE_MEMBER AS (
        SELECT
            M.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L
          ON M.MBER_NO = L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A
          ON M.MBER_NO = A.MBER_NO
        WHERE TO_DATE(:STDR_MT_END_DT, 'YYYYMMDD')
              BETWEEN TO_DATE(M.FRST_REGIST_DT)
              AND COALESCE(
                    A.ACTUAL_DT,
                    TO_DATE('9999-12-31')
                  )
    ),
    
    /* =========================================================
       8. 감액 원천
       ========================================================= */
    DECREASE_SOURCE AS (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            A.ACMSLT_DEPT_CD,
            A.SPNSR_BSNS_ID,
    
            SUM(A.SPNSR_AMT) OVER (
                PARTITION BY
                    A.MBER_NO,
                    LEFT(A.OCCRRNC_DE, 6)
            ) AS MAMT,
    
            ROW_NUMBER() OVER (
                PARTITION BY
                    A.MBER_NO,
                    LEFT(A.OCCRRNC_DE, 6)
                ORDER BY
                    A.SPNSR_NO DESC,
                    A.OCCRRNC_DE DESC,
                    A.SER_NO DESC,
                    A.SPNSR_BSNS_NO DESC
            ) AS SNUM
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
    
        WHERE A.DVLP_DIV_CD IN ('2', '3')
          AND LEFT(A.OCCRRNC_DE, 6)
              BETWEEN :FRST_MT AND :STDR_MT
    ),
    
    /* =========================================================
       9. 감액 팩트
       ========================================================= */
    DECREASE_FACT AS (
        SELECT
            D.STRD_MT,
            D.SPNSR_NO,
            D.SPNSR_BSNS_NO,
            D.MBER_NO,
            D.SPNSR_BSNS_ID,
            B.CPR_DIV_CD,
            MAP.DEPT4_ID,
    
            CASE
                WHEN TO_CHAR(M.FRST_REGIST_DT, 'YYYY')
                        = LEFT(:STDR_MT, 4)
                 AND TO_CHAR(S.FRST_REGIST_DT, 'YYYY')
                        = LEFT(:STDR_MT, 4)
                    THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            D.MAMT AS SPNSR_AMT,
            D.MAMT / 10000.0 AS SPNSR_AMT_CNT
    
        FROM DECREASE_SOURCE D
    
        JOIN MEMBER_MONTH M
          ON D.MBER_NO = M.MBER_NO
    
        JOIN BUSINESS_DIM B
          ON D.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
          ON D.MBER_NO = S.MBER_NO
         AND D.SPNSR_NO = S.SPNSR_NO
    
        LEFT JOIN DEPT_MAP MAP
          ON COALESCE(D.ACMSLT_DEPT_CD, 'Z~')
           = MAP.SRC_DEPT_ID
    
        WHERE D.MAMT < 0
          AND D.SNUM = 1
    ),
    
    /* =========================================================
       10. 활동 팩트
       ========================================================= */
    ACTIVE_HISTORY AS (
        SELECT
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            A.SPNSR_BSNS_ID,
    
            SUM(A.SPNSR_AMT) OVER (
                PARTITION BY
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
            ) AS SUM_AMT,
    
            ROW_NUMBER() OVER (
                PARTITION BY
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
                ORDER BY
                    A.OCCRRNC_DE DESC,
                    A.SER_NO DESC
            ) AS RNUM
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
    
        WHERE A.OCCRRNC_DE <= :STDR_MT_31
    ),
    
    ACTIVE_FACT AS (
        SELECT
            :STDR_MT AS STRD_MT,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.MBER_NO,
            A.SPNSR_BSNS_ID,
            COALESCE(P.CPR_DIV_CD, 'I')
                AS CPR_DIV_CD,
            MAP.DEPT4_ID,
    
            CASE
                WHEN TO_CHAR(M.FRST_REGIST_DT, 'YYYY')
                        = LEFT(:STDR_MT, 4)
                 AND TO_CHAR(S.FRST_REGIST_DT, 'YYYY')
                        = LEFT(:STDR_MT, 4)
                    THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            A.SUM_AMT AS SPNSR_AMT,
            A.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
    
        FROM ACTIVE_HISTORY A
    
        JOIN ACTIVE_MEMBER AM
          ON A.MBER_NO = AM.MBER_NO
    
        JOIN MEMBER_MONTH M
          ON A.MBER_NO = M.MBER_NO
    
        JOIN BUSINESS_DIM B
          ON A.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
    
        LEFT JOIN SETLE_MONTH P
          ON A.MBER_NO = P.MBER_NO
         AND B.CPR_DIV_CD = P.CPR_DIV_CD
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
          ON A.MBER_NO = S.MBER_NO
         AND A.SPNSR_NO = S.SPNSR_NO
    
        LEFT JOIN DEPT_MAP MAP
          ON COALESCE(S.ACMSLT_DEPT_CD, 'Z~')
           = MAP.SRC_DEPT_ID
    
        WHERE A.RNUM = 1
          AND A.SUM_AMT > 0
    ),
    
    /* =========================================================
       11. 당월 감액
       ========================================================= */
    MONTH_DECREASE AS (
        SELECT
            SPNSR_BSNS_ID,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            CPR_DIV_CD,
            STRD_MT,
    
            COUNT(DISTINCT MBER_NO) AS WJXBFS1,
            SUM(ABS(SPNSR_AMT_CNT)) AS WJXBFS2
    
        FROM DECREASE_FACT
    
        WHERE STRD_MT = :STDR_MT
    
        GROUP BY
            SPNSR_BSNS_ID,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            CPR_DIV_CD,
            STRD_MT
    ),
    
    /* =========================================================
       12. YTD 감액
       ========================================================= */
    YTD_DECREASE AS (
        SELECT
            SPNSR_BSNS_ID,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            CPR_DIV_CD,
            :STDR_MT AS STRD_MT,
    
            COUNT(DISTINCT MBER_NO) AS WJXBFS1,
            SUM(ABS(SPNSR_AMT_CNT)) AS WJXBFS2
    
        FROM DECREASE_FACT
    
        WHERE STRD_MT
              BETWEEN :FRST_MT AND :STDR_MT
    
        GROUP BY
            SPNSR_BSNS_ID,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            CPR_DIV_CD
    ),
    
    /* =========================================================
       13. 기준월 활동
       ========================================================= */
    MONTH_ACTIVE AS (
        SELECT
            SPNSR_BSNS_ID,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            CPR_DIV_CD,
            STRD_MT,
    
            COUNT(DISTINCT MBER_NO) AS WJXBFS1,
            SUM(SPNSR_AMT_CNT) AS WJXBFS2
    
        FROM ACTIVE_FACT
    
        GROUP BY
            SPNSR_BSNS_ID,
            NEW_OLD_DIV_CD,
            DEPT4_ID,
            CPR_DIV_CD,
            STRD_MT
    ),
    
    /* =========================================================
       14. 기존 RST 생성
       ========================================================= */
    RST AS (
        SELECT
    
            COALESCE(
                MD.STRD_MT,
                YD.STRD_MT,
                MA.STRD_MT
            ) AS STRD_MT,
    
            CPR.CPR_DIV_NM,
    
            BSNS.SPNSR_BSNS_NM,
    
            CASE
                WHEN COALESCE(
                    MD.NEW_OLD_DIV_CD,
                    YD.NEW_OLD_DIV_CD,
                    MA.NEW_OLD_DIV_CD
                ) = '1'
                    THEN '신규'
    
                WHEN COALESCE(
                    MD.NEW_OLD_DIV_CD,
                    YD.NEW_OLD_DIV_CD,
                    MA.NEW_OLD_DIV_CD
                ) = '2'
                    THEN '기존'
    
                ELSE '없음'
            END AS NEW_OLD_DIV_NM,
    
            D4.DEPT4_NM,
    
            MD.WJXBFS1 AS WJXBFS1,
            MD.WJXBFS2 AS WJXBFS2,
            YD.WJXBFS1 AS WJXBFS3,
            YD.WJXBFS2 AS WJXBFS4,
            MA.WJXBFS1 AS WJXBFS5,
            MA.WJXBFS2 AS WJXBFS6
    
        FROM MONTH_DECREASE MD
    
        FULL OUTER JOIN YTD_DECREASE YD
          ON MD.CPR_DIV_CD = YD.CPR_DIV_CD
         AND MD.DEPT4_ID = YD.DEPT4_ID
         AND MD.NEW_OLD_DIV_CD = YD.NEW_OLD_DIV_CD
         AND MD.SPNSR_BSNS_ID = YD.SPNSR_BSNS_ID
         AND MD.STRD_MT = YD.STRD_MT
    
        FULL OUTER JOIN MONTH_ACTIVE MA
          ON COALESCE(
                MD.CPR_DIV_CD,
                YD.CPR_DIV_CD
             ) = MA.CPR_DIV_CD
    
         AND COALESCE(
                MD.DEPT4_ID,
                YD.DEPT4_ID
             ) = MA.DEPT4_ID
    
         AND COALESCE(
                MD.NEW_OLD_DIV_CD,
                YD.NEW_OLD_DIV_CD
             ) = MA.NEW_OLD_DIV_CD
    
         AND COALESCE(
                MD.SPNSR_BSNS_ID,
                YD.SPNSR_BSNS_ID
             ) = MA.SPNSR_BSNS_ID
    
         AND COALESCE(
                MD.STRD_MT,
                YD.STRD_MT
             ) = MA.STRD_MT
    
        LEFT JOIN CPR_DIM CPR
          ON COALESCE(
                MD.CPR_DIV_CD,
                YD.CPR_DIV_CD,
                MA.CPR_DIV_CD
             ) = CPR.CPR_DIV_CD
    
        LEFT JOIN BUSINESS_DIM BSNS
          ON COALESCE(
                MD.SPNSR_BSNS_ID,
                YD.SPNSR_BSNS_ID,
                MA.SPNSR_BSNS_ID
             ) = BSNS.SPNSR_BSNS_ID
    
        LEFT JOIN DEPT4_DIM D4
          ON COALESCE(
                MD.DEPT4_ID,
                YD.DEPT4_ID,
                MA.DEPT4_ID
             ) = D4.DEPT4_ID
    
        WHERE COALESCE(
                MD.CPR_DIV_CD,
                YD.CPR_DIV_CD,
                MA.CPR_DIV_CD
              ) = 'I'
    ),
    
    /* =========================================================
       15. 후원사업 그룹
       후원사업별 실제 존재 데이터 기준
       ========================================================= */
    BUSINESS_GROUP AS (
        SELECT DISTINCT
            STRD_MT,
            CPR_DIV_NM,
            CASE
                WHEN SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE SPNSR_BSNS_NM
            END AS SPNSR_BSNS_GRP_NM
        FROM RST
    ),
    
    /* =========================================================
       16. 원하는 3개 구분 생성
       기존      → 기존
       신규+본부 → 신규 / 본부
       신규+지부 → 신규 / 지부
       ========================================================= */
    ROW_TYPE AS (
        SELECT
            '기존' AS NEW_EXST_DIV_NM,
            '기존' AS HDQ_BRNCH_GRP_NM
    
        UNION ALL
    
        SELECT
            '신규' AS NEW_EXST_DIV_NM,
            '본부' AS HDQ_BRNCH_GRP_NM
    
        UNION ALL
    
        SELECT
            '신규' AS NEW_EXST_DIV_NM,
            '지부' AS HDQ_BRNCH_GRP_NM
    ),
    
    /* =========================================================
       17. 후원사업 그룹 × 3개 구분
       → 사업그룹별 무조건 3행 생성
       ========================================================= */
    TARGET_ROWS AS (
        SELECT
            B.STRD_MT,
            B.CPR_DIV_NM,
            B.SPNSR_BSNS_GRP_NM,
            R.NEW_EXST_DIV_NM,
            R.HDQ_BRNCH_GRP_NM
        FROM BUSINESS_GROUP B
        CROSS JOIN ROW_TYPE R
    ),
    
    /* =========================================================
       18. 실제 데이터 집계
       기존은 본부/지부를 합산
       신규는 본부/지부를 각각 집계
       ========================================================= */
    FINAL_AGGR AS (
        SELECT
            STRD_MT,
            CPR_DIV_NM,
    
            CASE
                WHEN SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE SPNSR_BSNS_NM
            END AS SPNSR_BSNS_GRP_NM,
    
            /* 기존은 본부/지부 무관하게 하나로 통합 */
            CASE
                WHEN NEW_OLD_DIV_NM = '기존'
                    THEN '기존'
                ELSE '신규'
            END AS NEW_EXST_DIV_NM,
    
            /* 기존은 '기존', 신규는 실제 본부/지부 */
            CASE
                WHEN NEW_OLD_DIV_NM = '기존'
                    THEN '기존'
    
                WHEN NEW_OLD_DIV_NM = '신규'
                 AND DEPT4_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                WHEN NEW_OLD_DIV_NM = '신규'
                    THEN '지부'
    
                ELSE '기타'
            END AS HDQ_BRNCH_GRP_NM,
    
            SUM(WJXBFS2) AS VALUE1
    
        FROM RST
    
        GROUP BY
            STRD_MT,
            CPR_DIV_NM,
    
            CASE
                WHEN SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE SPNSR_BSNS_NM
            END,
    
            CASE
                WHEN NEW_OLD_DIV_NM = '기존'
                    THEN '기존'
                ELSE '신규'
            END,
    
            CASE
                WHEN NEW_OLD_DIV_NM = '기존'
                    THEN '기존'
    
                WHEN NEW_OLD_DIV_NM = '신규'
                 AND DEPT4_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                WHEN NEW_OLD_DIV_NM = '신규'
                    THEN '지부'
    
                ELSE '기타'
            END
    )
    
    /* =========================================================
       19. 최종 결과
       사업그룹별 반드시 3행
       ========================================================= */
    SELECT
        T.STRD_MT,
        :AGGR_TY_NM AS AGGR_TY_NM,
        T.CPR_DIV_NM,
        T.SPNSR_BSNS_GRP_NM,
        T.NEW_EXST_DIV_NM,
        T.HDQ_BRNCH_GRP_NM,
        NVL(F.VALUE1, 0) AS VALUE1,
        NULL AS VALUE2
    
    FROM TARGET_ROWS T
    
    LEFT JOIN FINAL_AGGR F
      ON T.STRD_MT = F.STRD_MT
     AND T.CPR_DIV_NM = F.CPR_DIV_NM
     AND T.SPNSR_BSNS_GRP_NM = F.SPNSR_BSNS_GRP_NM
     AND T.NEW_EXST_DIV_NM = F.NEW_EXST_DIV_NM
     AND T.HDQ_BRNCH_GRP_NM = F.HDQ_BRNCH_GRP_NM
    
    ORDER BY
        T.STRD_MT,
        T.CPR_DIV_NM,
        T.SPNSR_BSNS_GRP_NM,
        CASE
            WHEN T.NEW_EXST_DIV_NM = '기존' THEN 1
            WHEN T.NEW_EXST_DIV_NM = '신규'
             AND T.HDQ_BRNCH_GRP_NM = '본부' THEN 2
            WHEN T.NEW_EXST_DIV_NM = '신규'
             AND T.HDQ_BRNCH_GRP_NM = '지부' THEN 3
            ELSE 9
        END;
    
    RETURN 'SUCCESS: ' || :STDR_MT;
END;
$$;




