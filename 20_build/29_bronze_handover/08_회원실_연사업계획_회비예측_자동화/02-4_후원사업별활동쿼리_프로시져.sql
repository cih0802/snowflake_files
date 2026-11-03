-- 회원실 외비예측 백데이터. 파라미터 해당월 활동 실측치 삭제 후 재인입 프로시져. 
-- GNI_OP>내 리포트>01. 회비예측(월마감)>4. 신규기존X후원사업X본부지부별 활동(건) 레포트 스노우플레이크 이식
-- 기준년월을 입력받아 해당 월의 활동 중인 후원 데이터를 기반으로 신규·기존 회원과 본부·지부별 활동 후원금액을 집계하여 MM_SPNSR_CLS_AGGR_DATA에 적재한다.
-- 기준년월(YYYYMM)을 입력받아 유효성 및 미래 년월 여부를 검증하고, 해당 월의 기존 활동 집계 데이터(AGGR_TY_NM='활동')를 삭제 후 재산출한다.
-- 기준월 말까지의 후원 및 중단·재후원 이력을 기준으로 기준월 현재 활동 중인 회원과 후원 건을 선별한다.
-- 회원 최초등록연도와 후원 최초등록연도를 기준으로 신규·기존 회원을 구분하고, 실적부서 계층을 기준으로 신규 회원의 본부·지부를 구분한다.
-- 기준월의 회원별·후원사업별 결제정보를 활용하여 법인 구분을 적용하고, 사단 법인(CPR_DIV_CD='I') 대상으로 집계한다.
-- 후원사업명을 기준으로 일부 사업을 국내(사단) 그룹으로 통합하여 후원사업 그룹별 활동 후원금액을 산출한다.
-- 후원사업 그룹별로 기존/기존, 신규/본부, 신규/지부의 3개 조합을 항상 생성하며, 활동 실적이 없는 조합은 0으로 처리한다.
-- 활동 후원금액은 10,000원 단위로 환산하여 "활동건수"에 저장하고, 집계 유형은 활동, 결과는 MM_SPNSR_CLS_AGGR_DATA에 적재한다.

CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_INSERT_MM_SPNSR_CLS_AGGR_DATA4(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    STDR_MT VARCHAR;
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
    AGGR_TY_NM := '활동';
    /* ============================================================
       1. 전체 데이터 구성
    ============================================================ */
    
    DELETE
    FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WHERE STDR_MT = :STDR_MT
    AND AGGR_TY_NM = :AGGR_TY_NM;
    INSERT INTO GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WITH
    /* =========================================================================
       0. 파라미터
       ========================================================================= */
    PARAMS AS
    (
        SELECT
            :STDR_MT AS STRD_MT,
            'I'::VARCHAR AS CPR_DIV_CD
    ),
    
    PARAM_DATES AS
    (
        SELECT
            STRD_MT,
            CPR_DIV_CD,
    
            STRD_MT || '31' AS MONTH_31,
    
            LAST_DAY(
                TO_DATE(STRD_MT || '01', 'YYYYMMDD')
            ) AS MONTH_END,
    
            DATEADD(
                'DAY',
                1,
                DATEADD(
                    'MONTH',
                    1,
                    TO_DATE(STRD_MT || '01', 'YYYYMMDD')
                )
            ) AS SETLE_CUTOFF
    
        FROM PARAMS
    ),
    
    /* =========================================================================
       1. 실적부서 -> 본부/지부(DEPT4) 매핑
       ========================================================================= */
    DEPT_MAP_BASE AS
    (
        SELECT
            E.DEPT_ID AS SRC_DEPT_ID,
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
    ),
    
    DEPT_MAP AS
    (
        SELECT
            SRC_DEPT_ID,
            DEPT4_ID
        FROM DEPT_MAP_BASE
    
        UNION ALL
    
        SELECT
            'Z~' AS SRC_DEPT_ID,
            'Z~' AS DEPT4_ID
    ),
    
    /* =========================================================================
       2. DEPT4 차원
       ========================================================================= */
    DEPT4_DIM_BASE AS
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
    ),
    
    DEPT4_DIM AS
    (
        SELECT
            DEPT4_ID,
            DEPT4_NM,
            SORT_ORDR
        FROM DEPT4_DIM_BASE
    
        UNION ALL
    
        SELECT
            'Z~' AS DEPT4_ID,
            '없음' AS DEPT4_NM,
            999 AS SORT_ORDR
    ),
    
    /* =========================================================================
       3. 법인 차원
       ========================================================================= */
    CPR_DIM AS
    (
        SELECT DISTINCT
            D.DTL_CD_ID AS CPR_DIV_CD,
            D.DTL_CD_NM AS CPR_DIV_NM,
            D.SORT_ORDR
        FROM GN_DW.BRONZE_CRM.TC_CMMN_CD C
        JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD D
          ON C.CD_ID = D.CD_ID
        WHERE D.CD_ID = 'CM019'
    ),
    
    /* =========================================================================
       4. 후원사업 차원
       ========================================================================= */
    BUSINESS_DIM_BASE AS
    (
        SELECT
            S.SPNSR_BSNS_ID,
            S.SPNSR_BSNS_NM,
            S.SORT_ORDR,
    
            CASE
                WHEN S.CPR_DIV_CD = '1' THEN 'I'
                WHEN S.CPR_DIV_CD = '2' THEN 'S'
                ELSE S.CPR_DIV_CD
            END AS CPR_DIV_CD
    
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO S
    ),
    
    BUSINESS_DIM AS
    (
        SELECT
            SPNSR_BSNS_ID,
            SPNSR_BSNS_NM,
            SORT_ORDR,
            CPR_DIV_CD
        FROM BUSINESS_DIM_BASE
    
        UNION ALL
    
        SELECT
            '99' AS SPNSR_BSNS_ID,
            '없음' AS SPNSR_BSNS_NM,
            999 AS SORT_ORDR,
            'Z' AS CPR_DIV_CD
    
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM BUSINESS_DIM_BASE
            WHERE SPNSR_BSNS_ID = '99'
        )
    ),
    
    /* =========================================================================
       5. 회원+후원사업법인별 기준월 최신 결제정보
       ========================================================================= */
    SETLE_RANKED AS
    (
        SELECT
            U.MBER_NO,
            U.CPR_DIV_CD,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    U.MBER_NO,
                    U.CPR_DIV_CD
                ORDER BY
                    U.SETLE_KEY DESC
            ) AS RNUM
    
        FROM
        (
            SELECT
                1 AS SETLE_DIV_CD,
                SETLE_KEY,
                MBER_NO,
                CPR_DIV_CD,
                FRST_REGIST_DT
            FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
    
            UNION ALL
    
            SELECT
                2 AS SETLE_DIV_CD,
                SETLE_KEY,
                MBER_NO,
                CPR_DIV_CD,
                REGIST_DT
            FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
        ) U
    
        CROSS JOIN PARAM_DATES P
    
        WHERE U.FRST_REGIST_DT <= P.SETLE_CUTOFF
    ),
    
    SETLE_MONTH AS
    (
        SELECT
            MBER_NO,
            CPR_DIV_CD
        FROM SETLE_RANKED
        WHERE RNUM = 1
    ),
    
    /* =========================================================================
       6. 기준월 말 활동회원
       ========================================================================= */
    
    LAST_DSCNTC AS
    (
        SELECT
            D.MBER_NO,
            D.SPNSR_DSCNTC_DE,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY D.MBER_NO
                ORDER BY D.SPNSR_DSCNTC_DE DESC
            ) AS RNUM
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC D
        CROSS JOIN PARAM_DATES P
    
        WHERE D.SPNSR_DSCNTC_DE <= P.MONTH_31
    ),
    
    LAST_RE_SPNSR AS
    (
        SELECT
            R.MBER_NO,
            R.RE_SPNSR_DE,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY R.MBER_NO
                ORDER BY R.RE_SPNSR_DE DESC
            ) AS RNUM
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR R
        CROSS JOIN PARAM_DATES P
    
        WHERE R.RE_SPNSR_DE <= P.MONTH_31
    ),
    
    LAST_ACTIVITY_DATE AS
    (
        SELECT
            D.MBER_NO,
    
            CASE
                WHEN R.RE_SPNSR_DE IS NULL
                    THEN DATEADD(
                        'DAY',
                        -1,
                        TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD')
                    )
    
                WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE
                    THEN DATEADD(
                        'DAY',
                        -1,
                        TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD')
                    )
    
                WHEN R.RE_SPNSR_DE < TO_CHAR(P.MONTH_END, 'YYYYMMDD')
                    THEN P.MONTH_END
    
                ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD')
    
            END AS ACTUAL_DT
    
        FROM LAST_DSCNTC D
    
        LEFT JOIN LAST_RE_SPNSR R
          ON D.MBER_NO = R.MBER_NO
         AND R.RNUM = 1
    
        CROSS JOIN PARAM_DATES P
    
        WHERE D.RNUM = 1
    ),
    
    HAS_LIVE_SPONSOR AS
    (
        SELECT DISTINCT
            S.MBER_NO
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
          ON S.SPNSR_NO = B.SPNSR_NO
    
        CROSS JOIN PARAM_DATES P
    
        WHERE TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD') <= P.MONTH_31
          AND COALESCE(
                B.SPNSR_DSCNTC_DE,
                '99991231'
              ) > P.MONTH_31
    ),
    
    ACTIVE_MEMBER AS
    (
        SELECT
            M.MBER_NO
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
    
        JOIN HAS_LIVE_SPONSOR L
          ON M.MBER_NO = L.MBER_NO
    
        LEFT JOIN LAST_ACTIVITY_DATE A
          ON M.MBER_NO = A.MBER_NO
    
        CROSS JOIN PARAM_DATES P
    
        WHERE P.MONTH_END
              BETWEEN TO_DATE(M.FRST_REGIST_DT)
                  AND COALESCE(
                        A.ACTUAL_DT,
                        '9999-12-31'::DATE
                      )
    ),
    
    /* =========================================================================
       7. 활동 이력
       ========================================================================= */
    ACTIVE_HISTORY AS
    (
        SELECT
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.OCCRRNC_DE,
            A.SER_NO,
            A.MBER_NO,
            A.SPNSR_BSNS_ID,
    
            SUM(
                A.SPNSR_AMT::NUMBER(38,4)
            ) OVER
            (
                PARTITION BY
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
            ) AS SUM_AMT,
    
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
                ORDER BY
                    A.OCCRRNC_DE DESC,
                    A.SER_NO DESC
            ) AS RNUM
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        CROSS JOIN PARAM_DATES P
    
        WHERE A.OCCRRNC_DE <= P.MONTH_31
    ),
    
    /* =========================================================================
       8. 활동회원 기준 데이터
       ========================================================================= */
    ACTIVE_BASE AS
    (
        SELECT
            P.STRD_MT AS STRD_MT,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.MBER_NO,
            A.SPNSR_BSNS_ID,
    
            CASE
                WHEN TO_CHAR(M.FRST_REGIST_DT, 'YYYY')
                     = LEFT(P.STRD_MT, 4)
                 AND TO_CHAR(S.FRST_REGIST_DT, 'YYYY')
                     = LEFT(P.STRD_MT, 4)
                    THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            MAP.DEPT4_ID,
    
            COALESCE(
                SETLE.CPR_DIV_CD,
                'I'
            ) AS CPR_DIV_CD,
    
            (
                A.SUM_AMT::NUMBER(38,10)
                / 10000.0
            ) AS SPNSR_AMT_CNT
    
        FROM ACTIVE_HISTORY A
    
        JOIN ACTIVE_MEMBER AM
          ON A.MBER_NO = AM.MBER_NO
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
          ON A.MBER_NO = M.MBER_NO
    
        JOIN BUSINESS_DIM B
          ON A.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
    
        LEFT JOIN SETLE_MONTH SETLE
          ON A.MBER_NO = SETLE.MBER_NO
         AND B.CPR_DIV_CD = SETLE.CPR_DIV_CD
    
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
          ON A.MBER_NO = S.MBER_NO
         AND A.SPNSR_NO = S.SPNSR_NO
    
        LEFT JOIN DEPT_MAP MAP
          ON COALESCE(
                S.ACMSLT_DEPT_CD,
                'Z~'
             ) = MAP.SRC_DEPT_ID
    
        CROSS JOIN PARAM_DATES P
    
        WHERE A.RNUM = 1
          AND A.SUM_AMT > 0
    ),
    
    /* =========================================================================
       9. 기존 / 신규 + 본부 / 지부 기준으로 1차 집계
          ----------------------------------------------------------------------
          기존:
            본부 + 지부를 모두 합쳐서 "기존 / 기존" 1행
    
          신규:
            신규 + 본부 -> 1행
            신규 + 지부 -> 1행
       ========================================================================= */
    FINAL_AGG AS
    (
        SELECT
            A.STRD_MT,
    
            CPR.CPR_DIV_NM,
    
            CASE
                WHEN BSNS.SPNSR_BSNS_NM IN
                (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE BSNS.SPNSR_BSNS_NM
            END AS SPNSR_BSNS_GRP_NM,
    
            /* 기존 / 신규 */
            CASE
                WHEN A.NEW_OLD_DIV_CD = '1'
                    THEN '신규'
                WHEN A.NEW_OLD_DIV_CD = '2'
                    THEN '기존'
                ELSE '없음'
            END AS NEW_EXST_DIV_NM,
    
            /* 기존은 무조건 "기존"
               신규만 본부 / 지부 구분 */
            CASE
                WHEN A.NEW_OLD_DIV_CD = '2'
                    THEN '기존'
    
                WHEN A.NEW_OLD_DIV_CD = '1'
                 AND D4.DEPT4_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                WHEN A.NEW_OLD_DIV_CD = '1'
                    THEN '지부'
    
                ELSE '기존'
            END AS HDQ_BRNCH_GRP_NM,
    
            SUM(
                A.SPNSR_AMT_CNT::NUMBER(38,10)
            )::NUMBER(38,10) AS VALUE1
    
        FROM ACTIVE_BASE A
    
        LEFT JOIN CPR_DIM CPR
          ON A.CPR_DIV_CD = CPR.CPR_DIV_CD
    
        LEFT JOIN DEPT4_DIM D4
          ON A.DEPT4_ID = D4.DEPT4_ID
    
        LEFT JOIN BUSINESS_DIM BSNS
          ON A.SPNSR_BSNS_ID = BSNS.SPNSR_BSNS_ID
    
        CROSS JOIN PARAM_DATES P
    
        WHERE P.CPR_DIV_CD IS NULL
           OR A.CPR_DIV_CD = P.CPR_DIV_CD
    
        GROUP BY
            A.STRD_MT,
            CPR.CPR_DIV_NM,
    
            CASE
                WHEN BSNS.SPNSR_BSNS_NM IN
                (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE BSNS.SPNSR_BSNS_NM
            END,
    
            CASE
                WHEN A.NEW_OLD_DIV_CD = '1'
                    THEN '신규'
                WHEN A.NEW_OLD_DIV_CD = '2'
                    THEN '기존'
                ELSE '없음'
            END,
    
            CASE
                WHEN A.NEW_OLD_DIV_CD = '2'
                    THEN '기존'
    
                WHEN A.NEW_OLD_DIV_CD = '1'
                 AND D4.DEPT4_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                WHEN A.NEW_OLD_DIV_CD = '1'
                    THEN '지부'
    
                ELSE '기존'
            END
    ),
    
    /* =========================================================================
       10. 반드시 출력해야 하는 3개 유형
       ========================================================================= */
    GROUP_TYPE AS
    (
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
    
    /* =========================================================================
       11. SPNSR_BSNS_GRP_NM별 기준 목록
       ========================================================================= */
    GROUP_BASE AS
    (
        SELECT DISTINCT
            STRD_MT,
            CPR_DIV_NM,
            SPNSR_BSNS_GRP_NM
        FROM FINAL_AGG
    )
    
    /* =========================================================================
       12. 최종 결과
          SPNSR_BSNS_GRP_NM별 무조건 3행 생성
       ========================================================================= */
    SELECT
        G.STRD_MT,
    
        :AGGR_TY_NM AS AGGR_TY_NM,
    
        G.CPR_DIV_NM,
    
        G.SPNSR_BSNS_GRP_NM,
    
        T.NEW_EXST_DIV_NM,
    
        T.HDQ_BRNCH_GRP_NM,
    
        COALESCE(
            A.VALUE1,
            0
        )::NUMBER(38,10) AS "활동건수",
    
        NULL AS VALUE2
    
    FROM GROUP_BASE G
    
    CROSS JOIN GROUP_TYPE T
    
    LEFT JOIN FINAL_AGG A
      ON  G.STRD_MT = A.STRD_MT
      AND G.CPR_DIV_NM = A.CPR_DIV_NM
      AND G.SPNSR_BSNS_GRP_NM = A.SPNSR_BSNS_GRP_NM
      AND T.NEW_EXST_DIV_NM = A.NEW_EXST_DIV_NM
      AND T.HDQ_BRNCH_GRP_NM = A.HDQ_BRNCH_GRP_NM
    
    ORDER BY
        G.STRD_MT,
        G.CPR_DIV_NM,
        G.SPNSR_BSNS_GRP_NM,
    
        CASE
            WHEN T.NEW_EXST_DIV_NM = '기존'
                THEN 1
    
            WHEN T.NEW_EXST_DIV_NM = '신규'
             AND T.HDQ_BRNCH_GRP_NM = '본부'
                THEN 2
    
            WHEN T.NEW_EXST_DIV_NM = '신규'
             AND T.HDQ_BRNCH_GRP_NM = '지부'
                THEN 3
    
            ELSE 9
        END
    ;
    
    RETURN 'SUCCESS: ' || :STDR_MT;
END;
$$;


