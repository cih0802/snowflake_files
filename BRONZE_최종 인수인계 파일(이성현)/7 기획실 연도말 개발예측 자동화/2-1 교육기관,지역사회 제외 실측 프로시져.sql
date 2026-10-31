-- 연도별 교육기관 / 지역사회 제외 실적 UPDATE 프로시져
-- MSTR GNIP10 > 내리포트 > 정혜영 > 개발목표예측 실측입력 레포트 집계 기준 스노우플레이크 이식
-- 기준년월(input_yyyymm)을 입력받아 후원개발 원천 데이터를 기준으로 신규·기존 회원, 부서, 후원사업 그룹별 월간 실적을 집계하고 연간 개발 목표 실적 데이터에 반영한다.
-- 기준년월은 YYYYMM 형식으로 검증하며, 유효하지 않거나 미래의 년월인 경우 처리를 종료한다.
-- 해당 월의 후원개발 원천 데이터를 대상으로 신규(1), 증액(2), 감액(3), 재후원(4), 해지(5) 등의 개발 구분을 활용하여 실적을 산출한다.
-- 신규·재후원 및 증액 데이터를 후원사업별로 검증·조정하여 실제 개발 실적 금액을 산출한다.
-- 후원사업, 법인, 실적부서 정보를 기준으로 데이터를 집계하고, 회원의 가입연도를 활용하여 신규·기존 회원 구분을 적용한다.
-- 부서 체계를 상위 조직 기준으로 재분류하고, 회원실, 나눔마케팅본부, 대면모금 등의 부서 구분으로 최종 집계한다.
-- 후원사업 그룹은 해외프로젝트, 국내, 결연, 기타의 4개 구분으로 표준화하여 집계한다.
-- 실제 데이터가 없는 조합도 기준 차원으로 생성한 후 실적을 0으로 반영하여, 연도·부서·신규/기존·후원사업 그룹별 실적을 월 단위로 관리한다.

최종 산출값은 ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA의 해당 월(M01~M12) 실적 컬럼만 갱신하며, 교육기관·지역사회 부서는 갱신 대상에서 제외한다.
CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA1(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    FROM_MT VARCHAR;
    TO_MT VARCHAR;
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
    FROM_MT := input_yyyymm;
    TO_MT := FROM_MT;
    -- 1. CTE
    CREATE OR REPLACE TEMPORARY TABLE GN_DW.SILVER.RESULT_TEMP AS   
    WITH
    PARAM AS (
        SELECT
            :FROM_MT AS FROM_MT,
            :TO_MT   AS TO_MT,
    
            TO_DATE(:FROM_MT || '01', 'YYYYMMDD') AS START_DE,
    
            DATEADD(
                MONTH,
                1,
                TO_DATE(:TO_MT || '01', 'YYYYMMDD')
            ) AS NEXT_DE
    ),
    
    -- 1. 조회기간 개발 원천
    DVLP_SOURCE AS (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            A.ACMSLT_DEPT_CD,
            A.SPNSR_BSNS_ID,
            A.DVLP_DIV_CD,
            CAST(A.SPNSR_AMT AS NUMBER(28, 4)) AS SPNSR_AMT
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT AS A
    
        CROSS JOIN PARAM AS P
    
        WHERE A.OCCRRNC_DE >= TO_CHAR(P.START_DE, 'YYYYMMDD')
          AND A.OCCRRNC_DE <  TO_CHAR(P.NEXT_DE, 'YYYYMMDD')
          AND A.DVLP_DIV_CD IN ('1', '2', '3', '4', '5')
    ),
    
    -- 신규·재후원 이벤트에 등장한 후원번호·후원사업번호
    RELEVANT_SPNSR_BSNS AS (
        SELECT DISTINCT
            S.SPNSR_NO,
            S.SPNSR_BSNS_NO
    
        FROM DVLP_SOURCE AS S
    
        WHERE S.DVLP_DIV_CD IN ('1', '4')
    ),
    
    -- 후원사업 월말 유지 판정용
    SPNSR_BSNS_PERIOD AS (
        SELECT
            S.SPNSR_NO,
            B.SPNSR_BSNS_NO,
    
            COALESCE(
                B.SPNSR_DSCNTC_DE,
                '99991231'
            ) AS DSC_DE
    
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR AS S
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS AS B
            ON S.SPNSR_NO = B.SPNSR_NO
    
        INNER JOIN RELEVANT_SPNSR_BSNS AS K
            ON B.SPNSR_NO      = K.SPNSR_NO
           AND B.SPNSR_BSNS_NO = K.SPNSR_BSNS_NO
    ),
    -- 2. 신규(1) · 재후원(4)
    NEW_RE_BASE AS (
        SELECT
            D.STRD_MT,
            D.OCCRRNC_DE,
            D.SPNSR_NO,
            D.SPNSR_BSNS_NO,
            D.SER_NO,
            D.MBER_NO,
            D.ACMSLT_DEPT_CD,
            D.SPNSR_BSNS_ID,
            D.DVLP_DIV_CD,
            D.SPNSR_AMT,
            SUM(D.SPNSR_AMT) OVER (
                PARTITION BY
                    D.SPNSR_NO,
                    D.SPNSR_BSNS_NO,
                    D.STRD_MT
            ) AS MAMT
        FROM DVLP_SOURCE AS D
        INNER JOIN SPNSR_BSNS_PERIOD AS P
            ON D.SPNSR_NO      = P.SPNSR_NO
           AND D.SPNSR_BSNS_NO = P.SPNSR_BSNS_NO
           AND P.DSC_DE > D.STRD_MT || '31'
        WHERE D.DVLP_DIV_CD IN ('1', '4')
    ),
    TRANSFORMED_NEW_RE AS (
        SELECT
            N.STRD_MT,
            N.OCCRRNC_DE,
            N.SPNSR_NO,
            N.SPNSR_BSNS_NO,
            N.SER_NO,
            N.MBER_NO,
            COALESCE(
                N.ACMSLT_DEPT_CD,
                'Z~'
            ) AS ACMSLT_DEPT_CD,
            N.SPNSR_BSNS_ID,
            N.DVLP_DIV_CD,
            CAST(N.SPNSR_AMT AS NUMBER(28, 4)) AS SPNSR_AMT
        FROM NEW_RE_BASE AS N
        WHERE N.MAMT > 0
    ),
    -- 3. 증액(2)
    INCREASE_BASE AS (
        SELECT
            D.STRD_MT,
            D.OCCRRNC_DE,
            D.SPNSR_NO,
            D.SPNSR_BSNS_NO,
            D.SER_NO,
            D.MBER_NO,
            D.ACMSLT_DEPT_CD,
            D.SPNSR_BSNS_ID,
            D.DVLP_DIV_CD,
            D.SPNSR_AMT,
    
            SUM(
                CASE
                    WHEN D.DVLP_DIV_CD IN ('2', '3')
                        THEN D.SPNSR_AMT
                    ELSE CAST(0 AS NUMBER(28, 4))
                END
            ) OVER (
                PARTITION BY
                    D.SPNSR_NO,
                    D.SPNSR_BSNS_NO,
                    D.STRD_MT
            ) AS SAMT,
    
            SUM(D.SPNSR_AMT) OVER (
                PARTITION BY
                    D.MBER_NO,
                    D.STRD_MT
            ) AS MAMT
    
        FROM DVLP_SOURCE AS D
    
        WHERE D.DVLP_DIV_CD IN ('2', '3', '5')
    ),
    INCREASE_FILTERED AS (
        SELECT
            I.STRD_MT,
            I.OCCRRNC_DE,
            I.SPNSR_NO,
            I.SPNSR_BSNS_NO,
            I.SER_NO,
            I.MBER_NO,
            I.ACMSLT_DEPT_CD,
            I.SPNSR_BSNS_ID,
            I.DVLP_DIV_CD,
            I.SPNSR_AMT,
            I.SAMT,
            I.MAMT,
    
            SUM(
                CASE
                    WHEN I.DVLP_DIV_CD = '3'
                        THEN I.SPNSR_AMT
                    ELSE CAST(0 AS NUMBER(28, 4))
                END
            ) OVER (
                PARTITION BY
                    I.MBER_NO,
                    I.STRD_MT
            ) AS DAMT
    
        FROM INCREASE_BASE AS I
    
        WHERE I.MAMT > 0
          AND (
                (
                    I.SAMT > 0
                    AND I.DVLP_DIV_CD = '2'
                )
                OR
                (
                    I.SAMT < 0
                    AND I.DVLP_DIV_CD = '3'
                )
          )
    ),
    INCREASE_ONLY2 AS (
        SELECT
            I.STRD_MT,
            I.OCCRRNC_DE,
            I.SPNSR_NO,
            I.SPNSR_BSNS_NO,
            I.SER_NO,
            I.MBER_NO,
            I.ACMSLT_DEPT_CD,
            I.SPNSR_BSNS_ID,
            I.SPNSR_AMT,
            I.SAMT,
            I.MAMT,
            I.DAMT,
    
            SUM(I.SAMT) OVER (
                PARTITION BY
                    I.MBER_NO,
                    I.STRD_MT
                ORDER BY
                    I.OCCRRNC_DE,
                    I.SER_NO
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS AAMT
    
        FROM INCREASE_FILTERED AS I
    
        WHERE I.DVLP_DIV_CD = '2'
    ),
    INCREASE_RANKED AS (
        SELECT
            I.STRD_MT,
            I.OCCRRNC_DE,
            I.SPNSR_NO,
            I.SPNSR_BSNS_NO,
            I.SER_NO,
            I.MBER_NO,
            I.ACMSLT_DEPT_CD,
            I.SPNSR_BSNS_ID,
    
            ROW_NUMBER() OVER (
                PARTITION BY
                    I.STRD_MT,
                    I.SPNSR_NO,
                    I.SPNSR_BSNS_NO
                ORDER BY
                    I.SER_NO
            ) AS RNUM,
    
            CASE
                WHEN I.MAMT <= I.SAMT
                     AND I.AAMT + I.DAMT <= I.MAMT
                    THEN I.AAMT + I.DAMT
    
                WHEN I.MAMT > I.SAMT
                     AND I.AAMT + I.DAMT <= I.SAMT
                    THEN I.AAMT + I.DAMT
    
                WHEN I.MAMT <= I.SAMT
                    THEN I.MAMT
    
                ELSE I.SAMT
            END AS RAMT
    
        FROM INCREASE_ONLY2 AS I
    
        WHERE I.AAMT - ABS(I.DAMT) > 0
    ),
    TRANSFORMED_INCREASE AS (
        SELECT
            I.STRD_MT,
            I.OCCRRNC_DE,
            I.SPNSR_NO,
            I.SPNSR_BSNS_NO,
            I.SER_NO,
            I.MBER_NO,
    
            COALESCE(
                I.ACMSLT_DEPT_CD,
                'Z~'
            ) AS ACMSLT_DEPT_CD,
    
            I.SPNSR_BSNS_ID,
    
            '2' AS DVLP_DIV_CD,
    
            CAST(I.RAMT AS NUMBER(28, 4)) AS SPNSR_AMT
    
        FROM INCREASE_RANKED AS I
    
        WHERE I.RNUM = 1
    ),
    -- 신규/재후원 + 증액
    TRANSFORMED_DVLP AS (
        SELECT *
        FROM TRANSFORMED_NEW_RE
    
        UNION ALL
    
        SELECT *
        FROM TRANSFORMED_INCREASE
    ),
    -- 4. 후원사업 차원
    BUSINESS_DIM_BASE AS (
        SELECT
            CAST(B.SPNSR_BSNS_ID AS VARCHAR) AS SPNSR_BSNS_ID,
    
            COALESCE(
                CAST(B.SPNSR_BSNS_ABRV_CD AS VARCHAR),
                '99'
            ) AS SPNSR_BSNS_ABRV_CD,
    
            CASE CAST(B.CPR_DIV_CD AS VARCHAR)
                WHEN '1' THEN 'I'
                WHEN '2' THEN 'S'
                ELSE COALESCE(
                    CAST(B.CPR_DIV_CD AS VARCHAR),
                    '0'
                )
            END AS CPR_DIV_CD
    
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO AS B
    ),
    
    
    BUSINESS_DIM AS (
        SELECT
            SPNSR_BSNS_ID,
            SPNSR_BSNS_ABRV_CD,
            CPR_DIV_CD
    
        FROM BUSINESS_DIM_BASE
    
        UNION ALL
    
        SELECT
            '99' AS SPNSR_BSNS_ID,
            '99' AS SPNSR_BSNS_ABRV_CD,
            'Z'  AS CPR_DIV_CD
    
        WHERE NOT EXISTS (
            SELECT 1
            FROM BUSINESS_DIM_BASE
            WHERE SPNSR_BSNS_ID = '99'
        )
    ),
    
    -- 5. REPORT FACT   
    REPORT_FACT AS (
        SELECT
            T.STRD_MT,
    
            COALESCE(
                B.CPR_DIV_CD,
                '0'
            ) AS CPR_DIV_CD,
    
            COALESCE(
                T.ACMSLT_DEPT_CD,
                'Z~'
            ) AS ACMSLT_DEPT_CD,
    
            CASE
                WHEN LEFT(T.OCCRRNC_DE, 4)
                     =
                     LEFT(
                         TO_CHAR(M.FRST_REGIST_DT, 'YYYY-MM-DD'),
                         4
                     )
                    THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            COALESCE(
                B.SPNSR_BSNS_ABRV_CD,
                '99'
            ) AS SPNSR_BSNS_ABRV_CD,
    
            T.DVLP_DIV_CD,
    
            CAST(
                CAST(T.SPNSR_AMT AS NUMBER(28, 4))
                / 10000.0
                AS NUMBER(38, 10)
            ) AS SPNSR_AMT_CNT
    
        FROM TRANSFORMED_DVLP AS T
    
        LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO AS M
            ON T.MBER_NO = M.MBER_NO
    
        LEFT JOIN BUSINESS_DIM AS B
            ON CAST(T.SPNSR_BSNS_ID AS VARCHAR)
             = B.SPNSR_BSNS_ID
    
        WHERE T.DVLP_DIV_CD IN ('1', '2', '4')
    ),
    
    
    -- 6. 최종 집계
    REPORT_AGG AS (
        SELECT
            F.CPR_DIV_CD,
            F.ACMSLT_DEPT_CD AS DEPT_ID,
            F.NEW_OLD_DIV_CD,
            F.SPNSR_BSNS_ABRV_CD,
            F.STRD_MT,
            SUM(F.SPNSR_AMT_CNT) AS WJXBFS1
    
        FROM REPORT_FACT AS F
    
        CROSS JOIN PARAM AS P
    
        WHERE F.STRD_MT >= P.FROM_MT
          AND F.STRD_MT <= P.TO_MT
          AND F.DVLP_DIV_CD IN ('1', '2', '4')
    
        GROUP BY
            F.CPR_DIV_CD,
            F.ACMSLT_DEPT_CD,
            F.NEW_OLD_DIV_CD,
            F.SPNSR_BSNS_ABRV_CD,
            F.STRD_MT
    ),
    -- 7. 코드 차원    
    CPR_DIM AS (
        SELECT
            CAST(D.DTL_CD_ID AS VARCHAR) AS CPR_DIV_CD,
            MAX(D.DTL_CD_NM) AS CPR_DIV_NM
    
        FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD AS D
    
        WHERE D.CD_ID = 'CM019'
    
        GROUP BY
            CAST(D.DTL_CD_ID AS VARCHAR)
    ),
    
    
    DEPT_DIM_BASE AS (
        SELECT
            CAST(D.DEPT_ID AS VARCHAR) AS DEPT_ID,
            MAX(D.DEPT_NM) AS DEPT_NM
    
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS D
    
        GROUP BY
            CAST(D.DEPT_ID AS VARCHAR)
    ),
    
    
    DEPT_DIM AS (
        SELECT
            DEPT_ID,
            DEPT_NM
    
        FROM DEPT_DIM_BASE
    
        UNION ALL
    
        SELECT
            'Z~' AS DEPT_ID,
            '없음' AS DEPT_NM
    
        WHERE NOT EXISTS (
            SELECT 1
            FROM DEPT_DIM_BASE
            WHERE DEPT_ID = 'Z~'
        )
    ),
    -- 부서 계층화
    DEPT_HIERARCHY AS (
        SELECT
            E.DEPT_ID AS SOURCE_DEPT_ID,
    
            /* 기존 로직의 DEPT4 */
            B.DEPT_ID AS DEPT4_ID,
            B.DEPT_NM AS DEPT4_NM,
    
            /* 상위 조직 */
            A.DEPT_ID AS UPPER_DEPT1_ID,
            A.DEPT_NM AS UPPER_DEPT1_NM,
    
            C.DEPT_ID AS UPPER_DEPT2_ID,
            C.DEPT_NM AS DEPT_DIV_NM,
    
            D.DEPT_ID AS UPPER_DEPT3_ID,
            D.DEPT_NM AS UPPER_DEPT3_NM
    
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
    
        /* 실적부서가 Z~인 경우 */
        SELECT
            'Z~' AS SOURCE_DEPT_ID,
    
            'Z~' AS DEPT4_ID,
            '없음' AS DEPT4_NM,
    
            'Z~' AS UPPER_DEPT1_ID,
            '없음' AS UPPER_DEPT1_NM,
    
            'Z~' AS UPPER_DEPT2_ID,
            '없음' AS DEPT_DIV_NM,
    
            'Z~' AS UPPER_DEPT3_ID,
            '없음' AS UPPER_DEPT3_NM
    ),
    -- 기존 DEPT4 차원   
    DEPT4_DIM AS (
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
    
    
    ABRV_DIM AS (
        SELECT
            CAST(D.DTL_CD_ID AS VARCHAR) AS SPNSR_BSNS_ABRV_CD,
            MAX(D.DTL_CD_NM) AS SPNSR_BSNS_GRP_NM
    
        FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD AS D
    
        WHERE D.CD_ID = 'CM003'
    
        GROUP BY
            CAST(D.DTL_CD_ID AS VARCHAR)
    ),
    
    
    -- 8. 전체 기준월 생성 FROM_MT ~ TO_MT 까지 모든 월 생성 TO_MT 이하만 사용
    MONTH_DIM_BASE AS (
        SELECT
            TO_CHAR(
                DATEADD(
                    MONTH,
                    SEQ4(),
                    TO_DATE(:FROM_MT || '01', 'YYYYMMDD')
                ),
                'YYYYMM'
            ) AS STRD_MT
    
        FROM TABLE(
            GENERATOR(
                ROWCOUNT => 120
            )
        )
    ),
    MONTH_DIM AS (
        SELECT
            M.STRD_MT
    
        FROM MONTH_DIM_BASE AS M
    
        WHERE M.STRD_MT <= :TO_MT
    ),
    
    
    -- 최종 보고서 차원 생성
    -- 최종 DEPT_DIV_NM 후보
    REPORT_DEPT_DIM AS (
        SELECT DISTINCT
            CASE
                WHEN H.DEPT_DIV_NM IN (
                    '회원실',
                    '나눔마케팅본부'
                )
                    THEN H.DEPT_DIV_NM
    
                WHEN D.DEPT_NM IN (
                    '캠페인기획2팀',
                    '소셜펀딩부'
                )
                    THEN '대면모금'
    
                ELSE H.DEPT_DIV_NM--'본부기타'
            END AS DEPT_DIV_NM
    
        FROM DEPT_DIM AS D
    
        LEFT JOIN DEPT_HIERARCHY AS H
            ON D.DEPT_ID = H.SOURCE_DEPT_ID
        WHERE H.UPPER_DEPT1_ID = 'ZA000001' -- 사단 본부 대상
    ),
    -- 최종 신규/기존 후보
    REPORT_NEW_OLD_DIM AS (
        SELECT '신규' AS NEW_EXST_DIV_NM
        UNION ALL
        SELECT '기존' AS NEW_EXST_DIV_NM
    ),
    
    -- 최종 후원사업 후보 4개만 존재하도록 고정 1. 해외프로젝트 2. 국내 3. 결연 4. 기타
    REPORT_BSNS_DIM AS (
        SELECT '해외프로젝트' AS SPNSR_BSNS_GRP_NM
        UNION ALL
        SELECT '국내'
        UNION ALL
        SELECT '결연'
        UNION ALL
        SELECT '기타'
    ),
    
    
    -- 최종 차원 전체 조합 실제 데이터에 존재하지 않는 조합도 생성
    REPORT_DIM AS (
        SELECT
            'I' AS CPR_DIV_CD,
            D.DEPT_DIV_NM,
            N.NEW_EXST_DIV_NM,
            B.SPNSR_BSNS_GRP_NM
    
        FROM REPORT_DEPT_DIM AS D
    
        CROSS JOIN REPORT_NEW_OLD_DIM AS N
    
        CROSS JOIN REPORT_BSNS_DIM AS B
    ),
    
    -- 기준월 × 최종 차원 전체 조합
    REPORT_GRID AS (
        SELECT
            M.STRD_MT,
            R.CPR_DIV_CD,
            R.DEPT_DIV_NM,
            R.NEW_EXST_DIV_NM,
            R.SPNSR_BSNS_GRP_NM
    
        FROM MONTH_DIM AS M
    
        CROSS JOIN REPORT_DIM AS R
    ),
    
    -- 10. 실제 데이터의 최종 차원별 집계
    REPORT_DIM_AGG AS (
        SELECT
            A.CPR_DIV_CD,
            CASE
                WHEN H.DEPT_DIV_NM IN (
                    '회원실',
                    '나눔마케팅본부'
                )
                    THEN H.DEPT_DIV_NM
                WHEN D.DEPT_NM IN (
                    '캠페인기획2팀',
                    '소셜펀딩부'
                )
                    THEN '대면모금'
                ELSE H.DEPT_DIV_NM--'본부기타'
            END AS DEPT_DIV_NM,
            CASE A.NEW_OLD_DIV_CD
                WHEN '1' THEN '신규'
                WHEN '2' THEN '기존'
                ELSE '없음'
            END AS NEW_EXST_DIV_NM,
            CASE
                WHEN B.SPNSR_BSNS_GRP_NM = '해외구호'
                    THEN '해외프로젝트'
    
                WHEN B.SPNSR_BSNS_GRP_NM = '국내'
                    OR B.SPNSR_BSNS_GRP_NM = '결연'
                    THEN B.SPNSR_BSNS_GRP_NM
    
                ELSE '기타'
            END AS SPNSR_BSNS_GRP_NM,
    
            A.STRD_MT,
    
            SUM(A.WJXBFS1) AS VALUE
    
        FROM REPORT_AGG AS A
    
        /* 현재 부서명 */
        LEFT JOIN DEPT_DIM AS D
            ON A.DEPT_ID = D.DEPT_ID
    
        /* 실적부서 → 상위 조직 */
        LEFT JOIN DEPT_HIERARCHY AS H
            ON A.DEPT_ID = H.SOURCE_DEPT_ID
    
        /* 법인 */
        LEFT JOIN CPR_DIM AS C
            ON A.CPR_DIV_CD = C.CPR_DIV_CD
    
        /* 후원사업 */
        LEFT JOIN ABRV_DIM AS B
            ON A.SPNSR_BSNS_ABRV_CD = B.SPNSR_BSNS_ABRV_CD
    
        WHERE A.CPR_DIV_CD = 'I'
    
        GROUP BY
            A.CPR_DIV_CD,
    
            CASE
                WHEN H.DEPT_DIV_NM IN (
                    '회원실',
                    '나눔마케팅본부'
                )
                    THEN H.DEPT_DIV_NM
    
                WHEN D.DEPT_NM IN (
                    '캠페인기획2팀',
                    '소셜펀딩부'
                )
                    THEN '대면모금'
    
                ELSE H.DEPT_DIV_NM--'본부기타'
            END,
    
            CASE A.NEW_OLD_DIV_CD
                WHEN '1' THEN '신규'
                WHEN '2' THEN '기존'
                ELSE '없음'
            END,
    
            CASE
                WHEN B.SPNSR_BSNS_GRP_NM = '해외구호'
                    THEN '해외프로젝트'
    
                WHEN B.SPNSR_BSNS_GRP_NM = '국내'
                    OR B.SPNSR_BSNS_GRP_NM = '결연'
                    THEN B.SPNSR_BSNS_GRP_NM
    
                ELSE '기타'
            END,
    
            A.STRD_MT
    ),
    -- 11. FINAL REPORT_GRID를 기준으로 LEFT JOIN 실제 실적이 없는 조합은 VALUE = NULL
    RESULT AS (
        SELECT
            '실적' AS DATA_TYPE_NM,
            LEFT(G.STRD_MT, 4) AS YEAR,
            CASE 
                WHEN G.DEPT_DIV_NM = '회원실' or G.DEPT_DIV_NM = '나눔마케팅본부' or G.DEPT_DIV_NM = '대면모금' THEN G.DEPT_DIV_NM
                ELSE '기타'
            END DEPT_DIV_NM,
        
            G.NEW_EXST_DIV_NM,
        
            G.SPNSR_BSNS_GRP_NM,
        
            SUM(A.VALUE) AS VALUE
        
        FROM REPORT_GRID AS G
        LEFT JOIN REPORT_DIM_AGG AS A
            ON A.CPR_DIV_CD          = G.CPR_DIV_CD
           AND A.DEPT_DIV_NM      = G.DEPT_DIV_NM
           AND A.NEW_EXST_DIV_NM      = G.NEW_EXST_DIV_NM
           AND A.SPNSR_BSNS_GRP_NM  = G.SPNSR_BSNS_GRP_NM
           AND A.STRD_MT             = G.STRD_MT
        WHERE G.STRD_MT = :FROM_MT   
        GROUP BY 
            G.STRD_MT,
            CASE 
                WHEN G.DEPT_DIV_NM = '회원실' or G.DEPT_DIV_NM = '나눔마케팅본부' or G.DEPT_DIV_NM = '대면모금' THEN G.DEPT_DIV_NM
                ELSE '기타'
            END,
            G.NEW_EXST_DIV_NM,
            G.SPNSR_BSNS_GRP_NM
        ORDER BY
            CASE 
                WHEN G.DEPT_DIV_NM = '회원실' or G.DEPT_DIV_NM = '나눔마케팅본부' or G.DEPT_DIV_NM = '대면모금' THEN G.DEPT_DIV_NM
                ELSE '기타'
            END,
            G.NEW_EXST_DIV_NM,
            G.SPNSR_BSNS_GRP_NM,
            G.STRD_MT
    ) 
    SELECT * FROM RESULT;
    SET UPDATE_SQL := 
        'UPDATE GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA AS T
         SET M' || RIGHT(:FROM_MT, 2) || ' = COALESCE(R.VALUE, 0)
         FROM (
             SELECT
                 T2.DATA_TYPE_NM,
                 T2.YEAR,
                 T2.DEPT_DIV_NM,
                 T2.NEW_EXST_DIV_NM,
                 T2.SPNSR_BSNS_GRP_NM,
                 R.VALUE
             FROM GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA T2
             LEFT JOIN GN_DW.SILVER.RESULT_TEMP R
                 ON T2.DATA_TYPE_NM = R.DATA_TYPE_NM
                AND T2.YEAR = R.YEAR
                AND T2.DEPT_DIV_NM = R.DEPT_DIV_NM
                AND T2.NEW_EXST_DIV_NM = R.NEW_EXST_DIV_NM
                AND T2.SPNSR_BSNS_GRP_NM = R.SPNSR_BSNS_GRP_NM
             WHERE T2.DATA_TYPE_NM = ''실적''
         ) R
         WHERE T.DATA_TYPE_NM = R.DATA_TYPE_NM
           AND T.YEAR = R.YEAR
           AND T.DEPT_DIV_NM = R.DEPT_DIV_NM
           AND T.NEW_EXST_DIV_NM = R.NEW_EXST_DIV_NM
           AND T.SPNSR_BSNS_GRP_NM = R.SPNSR_BSNS_GRP_NM
           AND T.DEPT_DIV_NM NOT IN (''교육기관'', ''지역사회'')';
    EXECUTE IMMEDIATE :UPDATE_SQL;
    RETURN 'SUCCESS: ' || :FROM_MT;
END;
$$;

