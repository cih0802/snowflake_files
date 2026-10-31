-- 회원실 외비예측 백데이터. 파라미터 해당월 중단 실측치 삭제 후 재인입 프로시져. 
-- GNI_OP>내 리포트>01. 회비예측(월마감)>2. 후원사업별 중단 레포트 집계 기준 스노우플레이크 이식
-- 기준년월을 입력받아 해당 월의 후원 중단 데이터를 기준으로 신규·기존 회원 및 본부·지부별 중단금액을 집계하여 MM_SPNSR_CLS_AGGR_DATA에 적재한다.
-- 기준년월(YYYYMM)을 입력받아 유효성 및 미래 년월 여부를 검증하고, 해당 월의 기존 중단 집계 데이터(AGGR_TY_NM='중단')를 삭제 후 재산출한다.
-- 회원번호와 중단일자를 기준으로 중복 중단 이력을 제거하고, 후원·후원사업별 중단금액을 월 단위로 집계한다.
-- 중단 발생연도와 회원 최초등록연도를 비교하여 신규·기존 회원으로 구분한다.
-- 실적부서의 부서 계층을 기준으로 본부·지부를 구분하며, 기존 회원은 본부·지부 구분 없이 기존으로 통합한다.
-- 후원사업명을 기준으로 일부 사업을 국내(사단) 그룹으로 통합하고, 사단 법인(CPR_DIV_CD='I') 대상으로 집계한다.
-- 후원사업별로 기존/기존, 신규/본부, 신규/지부의 3개 조합을 항상 생성하고, 중단 실적이 없는 조합은 0으로 처리한다.
-- 중단금액은 10,000원 단위로 환산하여 VALUE1에 저장하며, 집계 유형은 중단, 결과는 MM_SPNSR_CLS_AGGR_DATA에 적재한다.

CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_INSERT_MM_SPNSR_CLS_AGGR_DATA2(input_yyyymm VARCHAR)
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
    AGGR_TY_NM := '중단';

    DELETE
    FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WHERE STDR_MT = :STDR_MT
    AND AGGR_TY_NM = :AGGR_TY_NM;
    
    INSERT INTO GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WITH
    SPNSR_BSNS_DIM AS
    (
        /* MART.D_SPNSR_BSNS_INFO 재현 */
        SELECT
            A.SPNSR_BSNS_ID,
            A.SPNSR_BSNS_NM,
            A.SORT_ORDR,
            CASE
                WHEN A.CPR_DIV_CD = '1' THEN 'I'
                WHEN A.CPR_DIV_CD = '2' THEN 'S'
                ELSE A.CPR_DIV_CD
            END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO A
    
        UNION ALL
    
        SELECT
            '99' AS SPNSR_BSNS_ID,
            '없음' AS SPNSR_BSNS_NM,
            999 AS SORT_ORDR,
            'Z' AS CPR_DIV_CD
    ),
    
    CPR_DIV_DIM AS
    (
        /* MART.D_CPR_DIV_CD 재현 */
        SELECT DISTINCT
            B.DTL_CD_ID AS CPR_DIV_CD,
            B.DTL_CD_NM AS CPR_DIV_NM
        FROM GN_DW.BRONZE_CRM.TC_CMMN_CD A
        INNER JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD B
            ON A.CD_ID = B.CD_ID
        WHERE B.CD_ID = 'CM019'
    ),
    
    DEPT_HIERARCHY AS
    (
        /*
            원천 실적부서 코드에서
            본부/지부(DEPT4) 코드를 산출
        */
        SELECT
            E.DEPT_ID AS SOURCE_DEPT_ID,
            B.DEPT_ID AS DEPT4_ID
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B
            ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C
            ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D
            ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO E
            ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000'
          AND C.DEPT_ID <> 'ZC000029'
    
        UNION ALL
    
        SELECT
            'Z~' AS SOURCE_DEPT_ID,
            'Z~' AS DEPT4_ID
    ),
    
    DEPT4_DIM AS
    (
        /* MART.D_DEPT4_CD 재현 */
        SELECT
            B.DEPT_ID AS DEPT4_ID,
            B.DEPT_NM AS DEPT4_NM,
            B.SORT_ORDR
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B
            ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000'
          AND A.USE_YN = 'Y'
    
        UNION ALL
    
        SELECT
            'Z~' AS DEPT4_ID,
            '없음' AS DEPT4_NM,
            999 AS SORT_ORDR
    ),
    
    DSCNTC_KEY AS
    (
        /*
            회원번호와 중단일자가 같은 중단 이력이 여러 건이어도
            변동금액 데이터가 중복되지 않도록 키를 먼저 중복 제거
        */
        SELECT DISTINCT
            MBER_NO,
            SPNSR_DSCNTC_DE
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC
        WHERE LEFT(SPNSR_DSCNTC_DE, 6) = :STDR_MT
    ),
    
    DSCNTC_RAW AS
    (
        /*
            FN_MM_SPNSR_DVLP의
            중단 데이터(DVLP_DIV_CD = '5') 산출 로직 재현
        */
        SELECT
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    A.MBER_NO,
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO,
                    LEFT(A.OCCRRNC_DE, 6)
                ORDER BY A.SER_NO DESC
            ) AS SNUM,
    
            SUM(
                CAST(A.SPNSR_AMT AS DECIMAL(38, 0))
            ) OVER
            (
                PARTITION BY
                    A.MBER_NO,
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO,
                    LEFT(A.OCCRRNC_DE, 6)
            ) AS MAMT,
    
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            A.OCCRRNC_DE,
            A.SER_NO,
            A.MBER_NO,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.ACMSLT_DEPT_CD,
            A.SPNSR_BSNS_ID
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        INNER JOIN DSCNTC_KEY B
            ON A.MBER_NO = B.MBER_NO
           AND A.OCCRRNC_DE = B.SPNSR_DSCNTC_DE
    
        WHERE A.DVLP_DIV_CD = '5'
          AND LEFT(A.OCCRRNC_DE, 6) = :STDR_MT
    ),
    
    DSCNTC_MONTHLY AS
    (
        /*
            동일 회원·후원·후원사업의 월별 중단금액을 합산한 뒤
            가장 큰 SER_NO의 한 행만 유지
        */
        SELECT
            STRD_MT,
            OCCRRNC_DE,
            SER_NO,
            MBER_NO,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            COALESCE(ACMSLT_DEPT_CD, 'Z~') AS ACMSLT_DEPT_CD,
            SPNSR_BSNS_ID,
            MAMT AS SPNSR_AMT
        FROM DSCNTC_RAW
        WHERE SNUM = 1
    ),
    
    DETAIL_DATA AS
    (
        /* MART.F_MM_SPNSR_ACT 중단 데이터 생성 로직 재현 */
        SELECT
            A.STRD_MT,
    
            CASE
                WHEN S.CPR_DIV_CD = '1' THEN 'I'
                WHEN S.CPR_DIV_CD = '2' THEN 'S'
                ELSE S.CPR_DIV_CD
            END AS CPR_DIV_CD,
    
            A.SPNSR_BSNS_ID,
    
            /*
                중단 발생연도와 회원 최초등록연도가 같으면 신규,
                다르면 기존
            */
            CASE
                WHEN LEFT(A.OCCRRNC_DE, 4)
                     = TO_CHAR(M.FRST_REGIST_DT, 'YYYY')
                THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            H.DEPT4_ID,
    
            /* DW의 SPNSR_AMT_CNT 산식 */
            CAST(
                CAST(A.SPNSR_AMT AS DECIMAL(38, 0)) / 10000.0
                AS DECIMAL(38, 4)
            ) AS SPNSR_AMT_CNT
    
        FROM DSCNTC_MONTHLY A
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
            ON A.MBER_NO = M.MBER_NO
           AND TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM')
               <= :STDR_MT
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO S
            ON A.SPNSR_BSNS_ID = S.SPNSR_BSNS_ID
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR P
            ON A.MBER_NO = P.MBER_NO
           AND A.SPNSR_NO = P.SPNSR_NO
    
        LEFT JOIN DEPT_HIERARCHY H
            ON A.ACMSLT_DEPT_CD = H.SOURCE_DEPT_ID
    ),
    
    /* ============================================================
       기존/신규 + 본부/지부 기준으로 1차 집계
       기존은 여기서 HDQ_BRNCH_GRP_NM을 '기존'으로 통합
       ============================================================ */
    FINAL_BASE AS
    (
        SELECT
            D.STRD_MT AS STDR_MT,
            C.CPR_DIV_NM AS CPR_NM,
    
            CASE
                WHEN S.SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE S.SPNSR_BSNS_NM
            END AS SPNSR_BSNS_GRP_NM,
    
            CASE D.NEW_OLD_DIV_CD
                WHEN '1' THEN '신규'
                WHEN '2' THEN '기존'
            END AS NEW_EXST_DIV_NM,
    
            CASE
                /* 기존은 본부/지부 구분 없이 한 행으로 통합 */
                WHEN D.NEW_OLD_DIV_CD = '2'
                    THEN '기존'
    
                /* 신규만 본부/지부 구분 */
                WHEN D4.DEPT4_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                ELSE '지부'
            END AS HDQ_BRNCH_GRP_NM,
    
            NVL(SUM(ABS(D.SPNSR_AMT_CNT)), 0) AS VALUE1
    
        FROM DETAIL_DATA D
    
        LEFT JOIN CPR_DIV_DIM C
            ON D.CPR_DIV_CD = C.CPR_DIV_CD
    
        LEFT JOIN SPNSR_BSNS_DIM S
            ON D.SPNSR_BSNS_ID = S.SPNSR_BSNS_ID
    
        LEFT JOIN DEPT4_DIM D4
            ON D.DEPT4_ID = D4.DEPT4_ID
    
        WHERE D.CPR_DIV_CD = 'I'
    
        GROUP BY
            D.STRD_MT,
            C.CPR_DIV_NM,
    
            CASE
                WHEN S.SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE S.SPNSR_BSNS_NM
            END,
    
            D.NEW_OLD_DIV_CD,
    
            CASE
                WHEN D.NEW_OLD_DIV_CD = '2'
                    THEN '기존'
    
                WHEN D4.DEPT4_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                ELSE '지부'
            END
    ),
    
    /* ============================================================
       실제 존재하는 후원사업 그룹 목록
       ============================================================ */
    SPNSR_BSNS_LIST AS
    (
        SELECT DISTINCT
            STDR_MT,
            CPR_NM,
            SPNSR_BSNS_GRP_NM
        FROM FINAL_BASE
    ),
    
    /* ============================================================
       후원사업별 반드시 생성할 3개 행
       1. 기존 / 기존
       2. 신규 / 본부
       3. 신규 / 지부
       ============================================================ */
    ROW_TYPE AS
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
    
    /* ============================================================
       후원사업별 무조건 3행 생성
       데이터가 없는 조합은 VALUE1 = 0
       ============================================================ */
    FINAL_RESULT AS
    (
        SELECT
            A.STDR_MT,
            A.CPR_NM,
            A.SPNSR_BSNS_GRP_NM,
            B.NEW_EXST_DIV_NM,
            B.HDQ_BRNCH_GRP_NM,
    
            NVL(C.VALUE1, 0) AS VALUE1
    
        FROM SPNSR_BSNS_LIST A
    
        CROSS JOIN ROW_TYPE B
    
        LEFT JOIN FINAL_BASE C
            ON C.STDR_MT = A.STDR_MT
           AND C.CPR_NM = A.CPR_NM
           AND C.SPNSR_BSNS_GRP_NM = A.SPNSR_BSNS_GRP_NM
           AND C.NEW_EXST_DIV_NM = B.NEW_EXST_DIV_NM
           AND C.HDQ_BRNCH_GRP_NM = B.HDQ_BRNCH_GRP_NM
    )
    
    /* ============================================================
       최종 결과
       ============================================================ */
    SELECT
        STDR_MT,
        :AGGR_TY_NM AS AGGR_TY_NM,
        CPR_NM,
        SPNSR_BSNS_GRP_NM,
        NEW_EXST_DIV_NM,
        HDQ_BRNCH_GRP_NM,
        VALUE1,
        NULL AS VALUE2
    FROM FINAL_RESULT
    
    ORDER BY
        CPR_NM,
        SPNSR_BSNS_GRP_NM,
        CASE
            WHEN NEW_EXST_DIV_NM = '기존'
                THEN 1
            WHEN NEW_EXST_DIV_NM = '신규'
             AND HDQ_BRNCH_GRP_NM = '본부'
                THEN 2
            WHEN NEW_EXST_DIV_NM = '신규'
             AND HDQ_BRNCH_GRP_NM = '지부'
                THEN 3
        END;
    RETURN 'SUCCESS: ' || :STDR_MT;
END;
$$;


