
-- 회원실 외비예측 백데이터. 파라미터 해당월 개발 실측치 삭제 후 재인입 프로시져. 
-- GNI_OP>내 리포트>01. 회비예측(월마감)>1. 후원사업별 회원개발 레포트 집계 기준 스노우플레이크로 이식
-- 기준년월을 입력받아 해당 연도 1월부터 기준월까지의 후원개발 데이터를 기반으로 당월 및 연도 누적 후원개발 실적을 후원사업·신규/기존·본부/지부 기준으로 집계하여 MM_SPNSR_CLS_AGGR_DATA에 적재한다.
-- 입력받은 기준년월(YYYYMM)의 형식 및 유효성을 검증하고, 미래 년월 입력을 제한한다.
-- 기준연도 1월부터 기준월까지 월별 데이터를 생성하고, 공통코드·부서·후원사업 정보를 기준으로 집계에 필요한 차원을 구성한다.
-- 신규·재후원 및 증액 개발 데이터를 대상으로 후원사업 기간과 증액·감액 금액을 검증하여 실제 인정되는 후원개발 금액을 산출한다.
-- 회원 등록연도를 기준으로 신규/기존 회원을 구분하고, 부서 계층을 활용하여 후원개발 실적의 부서 정보를 구성한다.
-- 당월 실적과 연도 누적 실적을 각각 집계하고, 후원사업·법인구분·부서·신규/기존·개발구분별 후원개발 금액을 산출한다.
-- 사단 법인 데이터를 대상으로 후원사업명을 기준으로 일부 사업을 국내(사단)으로 통합하고, 신규/기존 및 부서 구분에 따라 기존, 신규-본부, 신규-지부의 3개 집계 행을 생성한다.
-- 최종 집계 결과를 AGGR_TY_NM='개발'로 구분하여 MM_SPNSR_CLS_AGGR_DATA에 적재하며, 기준월의 기존 개발 집계 데이터는 사전에 삭제 후 재생성한다.

CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_INSERT_MM_SPNSR_CLS_AGGR_DATA1(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    START_MT VARCHAR;
    END_MT VARCHAR;
    BASE_MT VARCHAR;
    AGGR_TY_NM VARCHAR;
    UPDATE_SQL VARCHAR;
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
    START_MT := input_yyyymm;
    END_MT := START_MT;
    BASE_MT := LEFT(:START_MT, 4) || '01';
    AGGR_TY_NM := '개발';

    --기존 데이터 삭제
    DELETE
    FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WHERE STDR_MT = :START_MT
    AND AGGR_TY_NM = :AGGR_TY_NM;

    --인입
    INSERT INTO GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
    WITH RECURSIVE
    -- 1. 조회월 생성 (시작연도 1월부터)
    MONTH_CTE AS (
        SELECT :BASE_MT AS STRD_MT
        UNION ALL
        SELECT TO_CHAR(
                   DATEADD(
                       MONTH,
                       1,
                       TO_DATE(STRD_MT || '01', 'YYYYMMDD')
                   ),
                   'YYYYMM'
               )
        FROM MONTH_CTE
        WHERE STRD_MT < :END_MT
    ),
    
    /* 2. 기준월 Dimension */
    STRD_MT_CD AS (
        SELECT
            STRD_MT,
            LEFT(STRD_MT, 4) || '-' || RIGHT(STRD_MT, 2) AS STRD_NM
        FROM MONTH_CTE
    ),
    
    /* 3. 연도 누적월 매핑 */
    STRD_ADD_MT AS (
        SELECT
            A.STRD_MT,
            B.STRD_MT AS STRD_ADD_MT
        FROM MONTH_CTE A
        JOIN MONTH_CTE B
            ON B.STRD_MT <= A.STRD_MT
           AND LEFT(B.STRD_MT, 4) = LEFT(A.STRD_MT, 4)
        WHERE A.STRD_MT BETWEEN :START_MT AND :END_MT
    ),
    
    /* 4. 공통코드 (ODS 원천 + 하드코딩) */
    CMMN_DTL_CD AS (
        SELECT DISTINCT
            B.CD_ID,
            B.DTL_CD_ID,
            B.DTL_CD_NM,
            B.SORT_ORDR,
            NVL(B.USE_YN, 'Y') AS USE_YN
        FROM GN_DW.BRONZE_CRM.TC_CMMN_CD A
        JOIN GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD B
            ON A.CD_ID = B.CD_ID
        WHERE B.CD_ID IN ('CM003', 'CM019', 'MM015')
    
        UNION ALL
    
        SELECT 'DMMM07', '1', '신규', 1, 'Y'
    
        UNION ALL
    
        SELECT 'DMMM07', '2', '기존', 2, 'Y'
    ),
    
    /* 5. 공통코드 메타 (없음 값 생성용) */
    CMMN_DTL_META AS (
        SELECT
            CD_ID,
            MAX(OCTET_LENGTH(DTL_CD_ID)) AS MSIZE,
            MAX(DTL_CD_ID) AS MVAL
        FROM CMMN_DTL_CD
        GROUP BY CD_ID
    ),
    
    /* 6. 공통코드 + 없음 값 통합 */
    CMMN_DTL_CD_FULL AS (
        SELECT
            CD_ID,
            DTL_CD_ID,
            DTL_CD_NM,
            SORT_ORDR,
            USE_YN
        FROM CMMN_DTL_CD
    
        UNION ALL
    
        SELECT
            CD_ID,
            CASE
                WHEN MVAL > 'A' AND MSIZE = 1 THEN 'Z'
                WHEN MVAL > 'A' AND MSIZE > 1 THEN 'Z~'
                WHEN MVAL < 'A' AND MSIZE = 1 THEN '99'
                WHEN MVAL < 'A' AND MSIZE = 2 THEN '999'
                WHEN MVAL < 'A' AND MSIZE = 3 THEN '9999'
                ELSE '99999'
            END AS DTL_CD_ID,
            '없음' AS DTL_CD_NM,
            999 AS SORT_ORDR,
            'Y' AS USE_YN
        FROM CMMN_DTL_META
    ),
    
    /* 7. Dimension: 후원사업 약칭 */
    SPNSR_BSNS_ABRV_CD_DIM AS (
        SELECT
            DTL_CD_ID AS SPNSR_BSNS_ABRV_CD,
            DTL_CD_NM AS SPNSR_BSNS_ABRV_NM,
            SORT_ORDR,
            USE_YN
        FROM CMMN_DTL_CD_FULL
        WHERE CD_ID = 'CM003'
    ),
    
    /* 8. Dimension: 법인구분 */
    CPR_DIV_CD_DIM AS (
        SELECT
            DTL_CD_ID AS CPR_DIV_CD,
            DTL_CD_NM AS CPR_DIV_NM,
            SORT_ORDR,
            USE_YN
        FROM CMMN_DTL_CD_FULL
        WHERE CD_ID = 'CM019'
    ),
    
    /* 9. Dimension: 신규/기존 */
    NEW_OLD_DIV_CD_DIM AS (
        SELECT
            DTL_CD_ID AS NEW_OLD_DIV_CD,
            DTL_CD_NM AS NEW_OLD_DIV_NM,
            SORT_ORDR,
            USE_YN
        FROM CMMN_DTL_CD_FULL
        WHERE CD_ID = 'DMMM07'
    ),
    
    /* 10. Dimension: 개발구분 */
    DVLP_DIV_CD_DIM AS (
        SELECT
            DTL_CD_ID AS DVLP_DIV_CD,
            DTL_CD_NM AS DVLP_DIV_NM,
            SORT_ORDR,
            USE_YN
        FROM CMMN_DTL_CD_FULL
        WHERE CD_ID = 'MM015'
    ),
    
    /* 11. 부서 기본정보 + Z~ 가상부서 */
    CM_DEPT_INFO AS (
        SELECT
            DEPT_ID,
            DEPT_NM,
            UPPER_DEPT_ID,
            SORT_ORDR,
            USE_YN,
            FRST_RGSTR_ID,
            FRST_REGIST_DT,
            LAST_UPDUSR_ID,
            LAST_UPDT_DT,
            ACMSLT_DEPT_YN,
            STATS_DEPT_LVL,
            ACMSLT_UPPER_DEPT_ID
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
    
        UNION ALL
    
        SELECT
            'Z~',
            'N/A',
            'ZV000000',
            SORT_ORDR,
            USE_YN,
            FRST_RGSTR_ID,
            FRST_REGIST_DT,
            LAST_UPDUSR_ID,
            LAST_UPDT_DT,
            ACMSLT_DEPT_YN,
            STATS_DEPT_LVL,
            'A000001'
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
        WHERE DEPT_ID = 'A000000'
    ),
    
    /* 12. 실적부서 계층 */
    DEPT_CD AS (
        SELECT
            E.DEPT_ID,
            E.DEPT_NM,
            D.DEPT_ID AS DEPT2_ID,
            C.DEPT_ID AS DEPT3_ID,
            B.DEPT_ID AS DEPT4_ID,
            A.DEPT_ID AS DEPT5_ID,
            E.SORT_ORDR,
            E.USE_YN,
            E.ACMSLT_DEPT_YN
        FROM CM_DEPT_INFO A
        JOIN CM_DEPT_INFO B
            ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        JOIN CM_DEPT_INFO C
            ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
        JOIN CM_DEPT_INFO D
            ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
        JOIN CM_DEPT_INFO E
            ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000'
          AND C.DEPT_ID <> 'ZC000029'
    
        UNION ALL
    
        SELECT
            'Z~',
            '없음',
            'Z~',
            'Z~',
            'Z~',
            'Z~',
            999,
            'Y',
            'Y'
    ),
    /* 13. 후원사업 정보 */
    SPNSR_BSNS_INFO AS (
        SELECT
            SPNSR_BSNS_ID,
            SPNSR_BSNS_NM,
            SPNSR_BSNS_ABRV_CD,
            SORT_ORDR,
            CASE
                WHEN CPR_DIV_CD = '1' THEN 'I'
                WHEN CPR_DIV_CD = '2' THEN 'S'
                ELSE CPR_DIV_CD
            END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    
        UNION ALL
    
        SELECT
            '99',
            '없음',
            '99',
            999,
            'Z'
    ),
    
    /* 14. 후원사업 진행정보 */
    SPNSR_BSNS_V AS (
        SELECT
            A.SPNSR_NO,
            B.SPNSR_BSNS_NO,
            B.SPNSR_BSNS_ID,
            A.MBER_NO,
            TO_CHAR(A.FRST_REGIST_DT, 'YYYYMMDD') AS FST_DE,
            NVL(B.SPNSR_DSCNTC_DE, '99991231') AS DSC_DE
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
            ON A.SPNSR_NO = B.SPNSR_NO
    ),
    
    /* 15. 신규/재후원 개발내역 */
    NEW_BASE AS (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            NVL(A.ACMSLT_DEPT_CD, 'Z~') AS ACMSLT_DEPT_CD,
            A.SPNSR_BSNS_ID,
            A.DVLP_DIV_CD,
            A.SPNSR_AMT,
    
            SUM(A.SPNSR_AMT) OVER (
                PARTITION BY
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO,
                    LEFT(A.OCCRRNC_DE, 6)
            ) AS MAMT
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
    
        JOIN SPNSR_BSNS_V B
            ON A.SPNSR_NO = B.SPNSR_NO
           AND A.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
           AND B.DSC_DE > LEFT(A.OCCRRNC_DE, 6) || '31'
    
        WHERE A.DVLP_DIV_CD IN ('1', '4')
          AND LEFT(A.OCCRRNC_DE, 6)
              BETWEEN :BASE_MT AND :END_MT
    ),
    
    DVLP_NEW AS (
        SELECT
            STRD_MT,
            OCCRRNC_DE,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            SER_NO,
            MBER_NO,
            ACMSLT_DEPT_CD,
            SPNSR_BSNS_ID,
            DVLP_DIV_CD,
            SPNSR_AMT
        FROM NEW_BASE
        WHERE MAMT > 0
    ),
    
    /* 16. 증액 계산 1단계 */
    INC_STEP1 AS (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            NVL(A.ACMSLT_DEPT_CD, 'Z~') AS ACMSLT_DEPT_CD,
            A.SPNSR_BSNS_ID,
            A.DVLP_DIV_CD,
            A.SPNSR_AMT,
    
            SUM(
                CASE
                    WHEN A.DVLP_DIV_CD IN ('2', '3')
                        THEN A.SPNSR_AMT
                    ELSE 0
                END
            ) OVER (
                PARTITION BY
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO,
                    LEFT(A.OCCRRNC_DE, 6)
            ) AS SAMT,
    
            SUM(A.SPNSR_AMT) OVER (
                PARTITION BY
                    A.MBER_NO,
                    LEFT(A.OCCRRNC_DE, 6)
            ) AS MAMT
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
    
        WHERE A.DVLP_DIV_CD IN ('2', '3', '5')
          AND LEFT(A.OCCRRNC_DE, 6)
              BETWEEN :BASE_MT AND :END_MT
    ),
    
    /* 17. 증액 계산 2단계 */
    INC_STEP2 AS (
        SELECT
            A.*,
    
            SUM(
                CASE
                    WHEN A.DVLP_DIV_CD = '3'
                        THEN A.SPNSR_AMT
                    ELSE 0
                END
            ) OVER (
                PARTITION BY
                    A.MBER_NO,
                    A.STRD_MT
            ) AS DAMT
    
        FROM INC_STEP1 A
    
        WHERE A.MAMT > 0
          AND (
                (A.SAMT > 0 AND A.DVLP_DIV_CD = '2')
             OR (A.SAMT < 0 AND A.DVLP_DIV_CD = '3')
          )
    ),
    
    /* 18. 증액 계산 3단계 */
    INC_STEP3 AS (
        SELECT
            A.*,
    
            SUM(A.SAMT) OVER (
                PARTITION BY
                    A.MBER_NO,
                    A.STRD_MT
                ORDER BY
                    A.OCCRRNC_DE,
                    A.SER_NO
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS AAMT
    
        FROM INC_STEP2 A
    
        WHERE A.DVLP_DIV_CD = '2'
    ),
    
    /* 19. 증액 최종 */
    INC_CALC AS (
        SELECT
            A.STRD_MT,
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            A.ACMSLT_DEPT_CD,
            A.SPNSR_BSNS_ID,
            '2' AS DVLP_DIV_CD,
    
            CASE
                WHEN A.MAMT <= A.SAMT
                     AND A.AAMT + A.DAMT <= A.MAMT
                    THEN A.AAMT + A.DAMT
    
                WHEN A.MAMT > A.SAMT
                     AND A.AAMT + A.DAMT <= A.SAMT
                    THEN A.AAMT + A.DAMT
    
                WHEN A.MAMT <= A.SAMT
                    THEN A.MAMT
    
                ELSE A.SAMT
            END AS SPNSR_AMT,
    
            ROW_NUMBER() OVER (
                PARTITION BY
                    A.STRD_MT,
                    A.SPNSR_NO,
                    A.SPNSR_BSNS_NO
                ORDER BY
                    A.SER_NO
            ) AS RNUM
    
        FROM INC_STEP3 A
    
        WHERE A.AAMT - ABS(A.DAMT) > 0
    ),
    
    DVLP_INC AS (
        SELECT
            STRD_MT,
            OCCRRNC_DE,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            SER_NO,
            MBER_NO,
            ACMSLT_DEPT_CD,
            SPNSR_BSNS_ID,
            DVLP_DIV_CD,
            SPNSR_AMT
        FROM INC_CALC
        WHERE RNUM = 1
    ),
    
    /* 20. 신규 + 증액 + 재후원 통합 */
    DVLP_BASE AS (
        SELECT * FROM DVLP_NEW
    
        UNION ALL
    
        SELECT * FROM DVLP_INC
    ),
    
    /* 21. Fact 생성 */
    FACT AS (
        SELECT
            A.STRD_MT,
            A.MBER_NO,
    
            NVL(B.DEPT2_ID, 'Z~') AS ACMSLT_DEPT2_CD,
            NVL(B.DEPT3_ID, 'Z~') AS ACMSLT_DEPT3_CD,
            NVL(B.DEPT4_ID, 'Z~') AS ACMSLT_DEPT4_CD,
    
            A.SPNSR_BSNS_ID,
    
            NVL(F.SPNSR_BSNS_ABRV_CD, '0') AS SPNSR_BSNS_ABRV_CD,
            NVL(F.CPR_DIV_CD, '0') AS CPR_DIV_CD,
    
            A.DVLP_DIV_CD,
    
            CASE
                WHEN LEFT(A.OCCRRNC_DE, 4)
                     = TO_VARCHAR(E.FRST_REGIST_DT, 'YYYY')
                    THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            A.SPNSR_AMT,
    
            CAST(
                A.SPNSR_AMT / 10000.0
                AS DECIMAL(38,6)
            ) AS SPNSR_AMT_CNT,
    
            A.OCCRRNC_DE
    
        FROM DVLP_BASE A
    
        LEFT JOIN DEPT_CD B
            ON A.ACMSLT_DEPT_CD = B.DEPT_ID
    
        LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO E
            ON A.MBER_NO = E.MBER_NO
    
        LEFT JOIN SPNSR_BSNS_INFO F
            ON A.SPNSR_BSNS_ID = F.SPNSR_BSNS_ID
    
        WHERE A.STRD_MT BETWEEN :BASE_MT AND :END_MT
          AND A.DVLP_DIV_CD IN ('1', '2', '4')
    ),
    
    /* 22. 당월 집계 */
    CURRENT_SUM AS (
        SELECT
            SPNSR_BSNS_ABRV_CD,
            SPNSR_BSNS_ID,
    
            ACMSLT_DEPT2_CD AS DEPT2_ID,
            NEW_OLD_DIV_CD,
    
            ACMSLT_DEPT3_CD AS DEPT3_ID,
            ACMSLT_DEPT4_CD AS DEPT4_ID,
    
            CPR_DIV_CD,
            STRD_MT,
            DVLP_DIV_CD,
    
            SUM(SPNSR_AMT_CNT) AS WJXBFS1,
            COUNT(DISTINCT MBER_NO) AS WJXBFS2,
            SUM(SPNSR_AMT) AS WJXBFS3
    
        FROM FACT
    
        WHERE STRD_MT BETWEEN :START_MT AND :END_MT
          AND DVLP_DIV_CD IN ('1', '2', '4')
    
        GROUP BY
            SPNSR_BSNS_ABRV_CD,
            SPNSR_BSNS_ID,
            ACMSLT_DEPT2_CD,
            NEW_OLD_DIV_CD,
            ACMSLT_DEPT3_CD,
            ACMSLT_DEPT4_CD,
            CPR_DIV_CD,
            STRD_MT,
            DVLP_DIV_CD
    ),
    
    /* 23. 연도 누적 집계 */
    CUMULATIVE_SUM AS (
        SELECT
            A.SPNSR_BSNS_ABRV_CD,
            A.SPNSR_BSNS_ID,
    
            A.ACMSLT_DEPT2_CD AS DEPT2_ID,
            A.NEW_OLD_DIV_CD,
    
            A.ACMSLT_DEPT3_CD AS DEPT3_ID,
            A.ACMSLT_DEPT4_CD AS DEPT4_ID,
    
            A.CPR_DIV_CD,
            M.STRD_MT,
            A.DVLP_DIV_CD,
    
            SUM(A.SPNSR_AMT_CNT) AS WJXBFS1,
            COUNT(DISTINCT A.MBER_NO) AS WJXBFS2
    
        FROM FACT A
    
        JOIN STRD_ADD_MT M
            ON A.STRD_MT = M.STRD_ADD_MT
    
        WHERE M.STRD_MT BETWEEN :START_MT AND :END_MT
          AND A.DVLP_DIV_CD IN ('1', '2', '4')
    
        GROUP BY
            A.SPNSR_BSNS_ABRV_CD,
            A.SPNSR_BSNS_ID,
            A.ACMSLT_DEPT2_CD,
            A.NEW_OLD_DIV_CD,
            A.ACMSLT_DEPT3_CD,
            A.ACMSLT_DEPT4_CD,
            A.CPR_DIV_CD,
            M.STRD_MT,
            A.DVLP_DIV_CD
    ),
    
    /* 24. 최종 집계 원천 */
    FINAL_BASE AS (
        SELECT
            COALESCE(C.STRD_MT, Y.STRD_MT) AS STRD_MT,
    
            CPR.CPR_DIV_NM AS CPR_NM,
    
            CASE
                WHEN SBI.SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE SBI.SPNSR_BSNS_NM
            END AS SPNSR_BSNS_GRP_NM,
    
            NOD.NEW_OLD_DIV_NM AS NEW_EXST_DIV_NM,
    
            /*
             * 기존은 본부/지부 구분 없이 하나로 통합
             * 신규만 본부/지부 구분
             */
            CASE
                WHEN NOD.NEW_OLD_DIV_NM = '기존'
                    THEN '기존'
    
                WHEN D4.DEPT_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                ELSE '지부'
            END AS HDQ_BRNCH_GRP_NM,
    
            NVL(SUM(C.WJXBFS1), 0) AS VALUE1
    
        FROM CURRENT_SUM C
    
        FULL OUTER JOIN CUMULATIVE_SUM Y
            ON C.CPR_DIV_CD = Y.CPR_DIV_CD
           AND C.DEPT2_ID = Y.DEPT2_ID
           AND C.DEPT3_ID = Y.DEPT3_ID
           AND C.DEPT4_ID = Y.DEPT4_ID
           AND C.DVLP_DIV_CD = Y.DVLP_DIV_CD
           AND C.NEW_OLD_DIV_CD = Y.NEW_OLD_DIV_CD
           AND C.SPNSR_BSNS_ABRV_CD = Y.SPNSR_BSNS_ABRV_CD
           AND C.SPNSR_BSNS_ID = Y.SPNSR_BSNS_ID
           AND C.STRD_MT = Y.STRD_MT
    
        LEFT JOIN STRD_MT_CD STM
            ON STM.STRD_MT = COALESCE(C.STRD_MT, Y.STRD_MT)
    
        LEFT JOIN CM_DEPT_INFO D4
            ON D4.DEPT_ID = COALESCE(C.DEPT4_ID, Y.DEPT4_ID)
    
        LEFT JOIN CM_DEPT_INFO D3
            ON D3.DEPT_ID = COALESCE(C.DEPT3_ID, Y.DEPT3_ID)
    
        LEFT JOIN CM_DEPT_INFO D2
            ON D2.DEPT_ID = COALESCE(C.DEPT2_ID, Y.DEPT2_ID)
    
        LEFT JOIN SPNSR_BSNS_INFO SBI
            ON SBI.SPNSR_BSNS_ID =
               COALESCE(C.SPNSR_BSNS_ID, Y.SPNSR_BSNS_ID)
    
        LEFT JOIN SPNSR_BSNS_ABRV_CD_DIM SBA
            ON SBA.SPNSR_BSNS_ABRV_CD =
               COALESCE(
                   C.SPNSR_BSNS_ABRV_CD,
                   Y.SPNSR_BSNS_ABRV_CD
               )
    
        LEFT JOIN DVLP_DIV_CD_DIM DVD
            ON DVD.DVLP_DIV_CD =
               COALESCE(C.DVLP_DIV_CD, Y.DVLP_DIV_CD)
    
        LEFT JOIN CPR_DIV_CD_DIM CPR
            ON CPR.CPR_DIV_CD =
               COALESCE(C.CPR_DIV_CD, Y.CPR_DIV_CD)
    
        LEFT JOIN NEW_OLD_DIV_CD_DIM NOD
            ON NOD.NEW_OLD_DIV_CD =
               COALESCE(
                   C.NEW_OLD_DIV_CD,
                   Y.NEW_OLD_DIV_CD
               )
    
        WHERE CPR.CPR_DIV_NM = '사단'
    
        GROUP BY
            COALESCE(C.STRD_MT, Y.STRD_MT),
            CPR.CPR_DIV_NM,
    
            CASE
                WHEN SBI.SPNSR_BSNS_NM IN (
                    '결식아동지원',
                    '국내아동권리보호사업(사단법인)',
                    '복지관후원',
                    '아동복지시설지원',
                    '아동학대예방',
                    '저소득가정지원'
                )
                    THEN '국내(사단)'
                ELSE SBI.SPNSR_BSNS_NM
            END,
    
            NOD.NEW_OLD_DIV_NM,
    
            CASE
                WHEN NOD.NEW_OLD_DIV_NM = '기존'
                    THEN '기존'
    
                WHEN D4.DEPT_NM IN ('본부', '본부(사복)')
                    THEN '본부'
    
                ELSE '지부'
            END
    ),
    
    /* 25. 후원사업별 기준 목록 */
    SPNSR_BSNS_3ROW AS (
        SELECT DISTINCT
            STRD_MT,
            CPR_NM,
            SPNSR_BSNS_GRP_NM
        FROM FINAL_BASE
    ),
    
    /* 26. 반드시 생성해야 하는 3개 행 */
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
    
    /* 27. 후원사업별 3행 강제 생성 */
    FINAL_3ROW AS (
        SELECT
            A.STRD_MT,
            A.CPR_NM,
            A.SPNSR_BSNS_GRP_NM,
    
            B.NEW_EXST_DIV_NM,
            B.HDQ_BRNCH_GRP_NM,
    
            NVL(C.VALUE1, 0) AS VALUE1
    
        FROM SPNSR_BSNS_3ROW A
    
        CROSS JOIN ROW_TYPE B
    
        LEFT JOIN FINAL_BASE C
            ON C.STRD_MT = A.STRD_MT
           AND C.CPR_NM = A.CPR_NM
           AND C.SPNSR_BSNS_GRP_NM = A.SPNSR_BSNS_GRP_NM
           AND C.NEW_EXST_DIV_NM = B.NEW_EXST_DIV_NM
           AND C.HDQ_BRNCH_GRP_NM = B.HDQ_BRNCH_GRP_NM
    )
    
    /* 28. 최종 결과 */
    SELECT
        STRD_MT,
        :AGGR_TY_NM AS AGGR_TY_NM,
        CPR_NM,
        SPNSR_BSNS_GRP_NM,
        NEW_EXST_DIV_NM,
        HDQ_BRNCH_GRP_NM,
        VALUE1,
        NULL AS VALUE2
    
    FROM FINAL_3ROW
    
    ORDER BY
        STRD_MT,
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
        END
    ;
    
    RETURN 'SUCCESS: ' || :START_MT;
END;
$$;


