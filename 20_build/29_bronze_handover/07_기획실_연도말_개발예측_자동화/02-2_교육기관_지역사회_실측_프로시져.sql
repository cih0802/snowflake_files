-- 연도별 교육기관 / 지역사회 실적 UPDATE 프로시져
-- MSTR GNIP10 > 내리포트 > 정혜영 > 개발목표예측 실측입력(교육기관지역사회) 레포트 집계 기준 스노우플레이크 이식
-- MSTR GNIP10 > 내리포트 > 정혜영 > 개발목표예측 실측입력(교육기관지역사회) 레포트 집계 기준 스노우플레이크 이식
-- 기준년월을 입력받아 후원개발 원천 데이터를 기준으로 교육기관·지역사회 캠페인의 월별 개발 실적을 집계하고, 연간 개발 목표 실적 테이블을 갱신한다.
-- 입력받은 기준년월(YYYYMM)의 형식 및 유효성을 검증하고, 미래 년월 입력을 제한한다.
-- 해당 월의 후원개발 원천 데이터를 조회하고, 신규(1)·증액(2)·감액(3)·재후원(4)·취소(5) 개발 구분을 대상으로 실적을 산출한다.
-- 신규·재후원은 후원사업 기간 및 월별 금액을 검증하여 유효한 개발 실적을 산출하고, 증액은 증액·감액 금액을 함께 고려하여 실제 인정되는 증액 금액을 계산한다.
-- 후원사업, 캠페인, 회원 정보를 결합하여 부서·상위 캠페인·신규/기존 회원·후원사업 그룹·법인 구분 기준으로 개발 실적을 집계한다.
-- 대상 부서를 기준으로 실적을 집계하고, 상위 캠페인 및 후원사업 그룹을 최종 표시 기준에 맞게 분류한다. 후원사업 그룹은 해외구호 → 해외프로젝트, 국내/결연은 그대로 유지하고 그 외는 기타로 분류한다.
-- 최종적으로 법인 구분이 개인(I) 인 실적 중 교육기관·지역사회 캠페인을 대상으로 ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA의 해당 연도·월(M01~M12) 실적을 갱신한다.

-- 교육기관과 지역사회는 부서기준으로는 시도본부 및 지부에 해당
-- 이 안에서 상위캠페인을 기준으로 한번 더 분개한것이 교육기관과 지역사회 
-- 교육기관 : 
--    U1255 초등캠페인, U1256 유아캠페인, U1257 청소년캠페인, U1197 2023 희망편지쓰기대회, U1198 2023 가족그림편지쓰기대회, 
--    U1199 2023 청소년캠페인
--    U1261 --260914 정혜영차장에게 추가 문의함. 교육기관에 포함된다고 함
-- 지역사회 : 
--    U0892 교회캠페인, U0897 지역사회(기타),  U1105 대학생캠페인, U1106 좋은이웃가게, U1107 신규기획사업, 
--    U1204 국제교류, U1263 지역네트워크, U1208 지부개발(사복), U1104 디지털마케팅, U0243 지역사회 네트워크, 
--    U1265 2024_가두캠페인, U1287 해외결식-Let's begin 캠페인, U0893 가두캠페인


CREATE OR REPLACE PROCEDURE GN_DW.SILVER.SP_ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA2(input_yyyymm VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    FROM_MT VARCHAR;
    TO_MT VARCHAR;
    START_DE VARCHAR;
    NEXT_DE VARCHAR;
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
    START_DE := FROM_MT || '01';
    NEXT_DE := TO_CHAR(
        DATEADD(MONTH,1,TO_DATE(TO_MT || '01', 'YYYYMMDD')),'YYYYMMDD'
    );

    -- 1. CTE
    CREATE OR REPLACE TEMPORARY TABLE GN_DW.SILVER.RESULT_TEMP AS
    WITH 
    -- 1-1. 대상 부서
    TARGET_DEPT AS
    (
        SELECT COLUMN1::VARCHAR AS DEPT_ID
        FROM VALUES
            ('D000116'),
            ('D000117'),
            ('D000118'),
            ('D000119'),
            ('D000120'),
            ('D000121'),
            ('D000123'),
            ('D000126'),
            ('D000139'),
            ('D000140'),
            ('E000029'),
            ('E000042'),
            ('E000117'),
            ('E001104'),
            ('E001105'),
            ('F001009'),
            ('E000067'),
            ('E000002')
    ),
    
    -- 1-2. 조회기간 개발 원천
    DVLP_SOURCE AS
    (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            A.OCCRRNC_DE,
            A.SPNSR_NO,
            A.SPNSR_BSNS_NO,
            A.SER_NO,
            A.MBER_NO,
            A.ACMSLT_DEPT_CD,
            A.CMPGN_CD,
            A.SPNSR_BSNS_ID,
            A.DVLP_DIV_CD,
            A.SPNSR_AMT::NUMBER(28, 4) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT AS A
        WHERE A.OCCRRNC_DE >= :START_DE
          AND A.OCCRRNC_DE <  :NEXT_DE
          AND A.DVLP_DIV_CD IN ('1', '2', '3', '4', '5')
    ),
    
    -- 1-3. 신규·재후원 대상 후원번호/후원사업
    RELEVANT_SPNSR_BSNS AS
    (
        SELECT DISTINCT
            S.SPNSR_NO,
            S.SPNSR_BSNS_NO
        FROM DVLP_SOURCE AS S
        WHERE S.DVLP_DIV_CD IN ('1', '4')
    ),
    
    -- 1-4. 후원사업 기간
    SPNSR_BSNS_PERIOD AS
    (
        SELECT
            S.SPNSR_NO,
            B.SPNSR_BSNS_NO,
            COALESCE(B.SPNSR_DSCNTC_DE, '99991231') AS DSC_DE
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR AS S
        INNER JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS AS B
            ON S.SPNSR_NO = B.SPNSR_NO
        INNER JOIN RELEVANT_SPNSR_BSNS AS K
            ON B.SPNSR_NO      = K.SPNSR_NO
           AND B.SPNSR_BSNS_NO = K.SPNSR_BSNS_NO
    ),
    
    -- 2. 신규(1)·재후원(4)    
    NEW_RE_BASE AS
    (
        SELECT
            D.STRD_MT,
            D.OCCRRNC_DE,
            D.SPNSR_NO,
            D.SPNSR_BSNS_NO,
            D.SER_NO,
            D.MBER_NO,
            D.ACMSLT_DEPT_CD,
            D.CMPGN_CD,
            D.SPNSR_BSNS_ID,
            D.DVLP_DIV_CD,
            D.SPNSR_AMT,
    
            SUM(D.SPNSR_AMT) OVER
            (
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
    
    -- 2-1. 개발 이벤트 변환 결과
    NEW_RE_TRANSFORMED AS
    (
        SELECT
            N.STRD_MT,
            N.OCCRRNC_DE,
            N.SPNSR_NO,
            N.SPNSR_BSNS_NO,
            N.SER_NO,
            N.MBER_NO,
            COALESCE(N.ACMSLT_DEPT_CD, 'Z~') AS ACMSLT_DEPT_CD,
            N.CMPGN_CD,
            N.SPNSR_BSNS_ID,
            N.DVLP_DIV_CD,
            N.SPNSR_AMT
        FROM NEW_RE_BASE AS N
        WHERE N.MAMT > 0
    ),
    
    -- 3. 증액(2)    
    INCREASE_BASE AS
    (
        SELECT
            D.STRD_MT,
            D.OCCRRNC_DE,
            D.SPNSR_NO,
            D.SPNSR_BSNS_NO,
            D.SER_NO,
            D.MBER_NO,
            D.ACMSLT_DEPT_CD,
            D.CMPGN_CD,
            D.SPNSR_BSNS_ID,
            D.DVLP_DIV_CD,
            D.SPNSR_AMT,
    
            SUM
            (
                CASE
                    WHEN D.DVLP_DIV_CD IN ('2', '3')
                        THEN D.SPNSR_AMT
                    ELSE 0::NUMBER(28,4)
                END
            ) OVER
            (
                PARTITION BY
                    D.SPNSR_NO,
                    D.SPNSR_BSNS_NO,
                    D.STRD_MT
            ) AS SAMT,
    
            SUM(D.SPNSR_AMT) OVER
            (
                PARTITION BY
                    D.MBER_NO,
                    D.STRD_MT
            ) AS MAMT
    
        FROM DVLP_SOURCE AS D
    
        WHERE D.DVLP_DIV_CD IN ('2', '3', '5')
    ),
    
    -- 3-2. 증액/감액 유효 행 필터
    INCREASE_FILTERED_BASE AS
    (
        SELECT
            I.*,
    
            SUM
            (
                CASE
                    WHEN I.DVLP_DIV_CD = '3'
                        THEN I.SPNSR_AMT
                    ELSE 0::NUMBER(28,4)
                END
            ) OVER
            (
                PARTITION BY
                    I.MBER_NO,
                    I.STRD_MT
            ) AS DAMT
    
        FROM INCREASE_BASE AS I
    
        WHERE I.MAMT > 0
    
          AND
          (
               (
                    I.SAMT > 0
                AND I.DVLP_DIV_CD = '2'
               )
            OR (
                    I.SAMT < 0
                AND I.DVLP_DIV_CD = '3'
               )
          )
    ),
    
    -- 3-3. 증액(2)만 추출하면서 회원·월별 증액 누계 계산
    INCREASE_ONLY2 AS
    (
        SELECT
            I.*,
    
            SUM(I.SAMT) OVER
            (
                PARTITION BY
                    I.MBER_NO,
                    I.STRD_MT
                ORDER BY
                    I.OCCRRNC_DE,
                    I.SER_NO
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS AAMT
    
        FROM INCREASE_FILTERED_BASE AS I
    
        WHERE I.DVLP_DIV_CD = '2'
    ),
    
    -- 3-4. 증액 인정금액 RAMT 계산
    INCREASE_RANKED_BASE AS
    (
        SELECT
            I.STRD_MT,
            I.OCCRRNC_DE,
            I.SPNSR_NO,
            I.SPNSR_BSNS_NO,
            I.SER_NO,
            I.MBER_NO,
            I.ACMSLT_DEPT_CD,
            I.CMPGN_CD,
            I.SPNSR_BSNS_ID,
    
            ROW_NUMBER() OVER
            (
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
    
    -- 3-5. 최종 증액 인정 행
    INCREASE_TRANSFORMED AS
    (
        SELECT
            I.STRD_MT,
            I.OCCRRNC_DE,
            I.SPNSR_NO,
            I.SPNSR_BSNS_NO,
            I.SER_NO,
            I.MBER_NO,
            COALESCE(I.ACMSLT_DEPT_CD, 'Z~') AS ACMSLT_DEPT_CD,
            I.CMPGN_CD,
            I.SPNSR_BSNS_ID,
            '2' AS DVLP_DIV_CD,
            I.RAMT::NUMBER(28,4) AS SPNSR_AMT
    
        FROM INCREASE_RANKED_BASE AS I
    
        WHERE I.RNUM = 1
    ),
    
    -- 4. 신규/재후원 + 증액 개발 이벤트 통합
    TRANSFORMED_DVLP AS
    (
        SELECT
            STRD_MT,
            OCCRRNC_DE,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            SER_NO,
            MBER_NO,
            ACMSLT_DEPT_CD,
            CMPGN_CD,
            SPNSR_BSNS_ID,
            DVLP_DIV_CD,
            SPNSR_AMT
        FROM NEW_RE_TRANSFORMED
    
        UNION ALL
    
        SELECT
            STRD_MT,
            OCCRRNC_DE,
            SPNSR_NO,
            SPNSR_BSNS_NO,
            SER_NO,
            MBER_NO,
            ACMSLT_DEPT_CD,
            CMPGN_CD,
            SPNSR_BSNS_ID,
            DVLP_DIV_CD,
            SPNSR_AMT
        FROM INCREASE_TRANSFORMED
    ),
    
    -- 5. 후원사업 차원
    BUSINESS_DIM AS
    (
        SELECT
            B.SPNSR_BSNS_ID::VARCHAR AS SPNSR_BSNS_ID,
    
            COALESCE(
                B.SPNSR_BSNS_ABRV_CD::VARCHAR,
                '0'
            ) AS SPNSR_BSNS_ABRV_CD,
    
            CASE B.CPR_DIV_CD::VARCHAR
                WHEN '1' THEN 'I'
                WHEN '2' THEN 'S'
                ELSE COALESCE(B.CPR_DIV_CD::VARCHAR, '0')
            END AS CPR_DIV_CD
    
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO AS B
    ),
    
    -- 6. 캠페인 차원
    CAMPAIGN_DIM AS
    (
        SELECT
            C.CMPGN_CD::VARCHAR AS CMPGN_CD,
    
            COALESCE(
                C.UPPER_CMPGN_CD::VARCHAR,
                'Z~'
            ) AS UPPER_CMPGN_CD
    
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG AS C
    ),
    
    -- 7. F_MM_SPNSR_DVLP_SUM 보고서 사용 컬럼 재현
    REPORT_FACT AS
    (
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
    
            COALESCE(
                C.UPPER_CMPGN_CD,
                'Z~'
            ) AS UPPER_CMPGN_CD,
    
            CASE
                WHEN LEFT(T.OCCRRNC_DE, 4)
                   = YEAR(M.FRST_REGIST_DT)::VARCHAR
                    THEN '1'
                ELSE '2'
            END AS NEW_OLD_DIV_CD,
    
            COALESCE(
                B.SPNSR_BSNS_ABRV_CD,
                '0'
            ) AS SPNSR_BSNS_ABRV_CD,
    
            T.DVLP_DIV_CD,
    
            (
                T.SPNSR_AMT::NUMBER(28,4)
                / 10000.0
            )::NUMBER(38,10) AS SPNSR_AMT_CNT
    
        FROM TRANSFORMED_DVLP AS T
    
        LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO AS M
            ON T.MBER_NO = M.MBER_NO
    
        LEFT JOIN BUSINESS_DIM AS B
            ON T.SPNSR_BSNS_ID::VARCHAR = B.SPNSR_BSNS_ID
    
        LEFT JOIN CAMPAIGN_DIM AS C
            ON T.CMPGN_CD::VARCHAR = C.CMPGN_CD
    
        WHERE T.DVLP_DIV_CD IN ('1', '2', '4')
    ),
    
    -- 8. 최종 집계   
    REPORT_AGG AS
    (
        SELECT
            F.ACMSLT_DEPT_CD AS DEPT_ID,
            F.STRD_MT,
            F.UPPER_CMPGN_CD,
            F.NEW_OLD_DIV_CD,
            F.SPNSR_BSNS_ABRV_CD,
            F.CPR_DIV_CD,
    
            SUM(F.SPNSR_AMT_CNT) AS WJXBFS1
    
        FROM REPORT_FACT AS F
    
        INNER JOIN TARGET_DEPT AS T
            ON F.ACMSLT_DEPT_CD = T.DEPT_ID
    
        WHERE F.STRD_MT >= :FROM_MT
          AND F.STRD_MT <= :TO_MT
          AND F.DVLP_DIV_CD IN ('1', '2', '4')
    
        GROUP BY
            F.ACMSLT_DEPT_CD,
            F.STRD_MT,
            F.UPPER_CMPGN_CD,
            F.NEW_OLD_DIV_CD,
            F.SPNSR_BSNS_ABRV_CD,
            F.CPR_DIV_CD
    ),
    
    -- 9. 표시용 차원
    DEPT_DIM AS
    (
        SELECT
            D.DEPT_ID::VARCHAR AS DEPT_ID,
            MAX(D.DEPT_NM) AS DEPT_NM
    
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS D
    
        GROUP BY
            D.DEPT_ID::VARCHAR
    ),
    
    -- 9-1. 조직계층 원천 (SOURCE_DEPT_ID = REPORT_AGG.DEPT_ID)
    DEPT_HIERARCHY_BASE AS
    (
        SELECT
            E.DEPT_ID::VARCHAR AS SOURCE_DEPT_ID,
    
            B.DEPT_ID::VARCHAR AS DEPT4_ID,
            B.DEPT_NM AS DEPT4_NM,
    
            A.DEPT_ID::VARCHAR AS UPPER_DEPT1_ID,
            A.DEPT_NM AS UPPER_DEPT1_NM,
    
            C.DEPT_ID::VARCHAR AS UPPER_DEPT2_ID,
            C.DEPT_NM AS UPPER_DEPT2_NM,
    
            D.DEPT_ID::VARCHAR AS UPPER_DEPT3_ID,
            D.DEPT_NM AS UPPER_DEPT3_NM
    
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS A
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS B
            ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS C
            ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS D
            ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
    
        INNER JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO AS E
            ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
    
        WHERE A.UPPER_DEPT_ID = 'ZV000000'
          AND C.DEPT_ID <> 'ZC000029'
    ),
    
    -- 9-2. 조직계층 1 DEPT_ID = 1 ROW 보장
    DEPT_HIERARCHY AS
    (
        SELECT
            SOURCE_DEPT_ID,
    
            MAX(DEPT4_ID) AS DEPT4_ID,
            MAX(DEPT4_NM) AS DEPT4_NM,
    
            MAX(UPPER_DEPT1_ID) AS UPPER_DEPT1_ID,
            MAX(UPPER_DEPT1_NM) AS UPPER_DEPT1_NM,
    
            MAX(UPPER_DEPT2_ID) AS UPPER_DEPT2_ID,
            MAX(UPPER_DEPT2_NM) AS UPPER_DEPT2_NM,
    
            MAX(UPPER_DEPT3_ID) AS UPPER_DEPT3_ID,
            MAX(UPPER_DEPT3_NM) AS UPPER_DEPT3_NM
    
        FROM DEPT_HIERARCHY_BASE
    
        GROUP BY
            SOURCE_DEPT_ID
    ),
    
    --9-3. 상위 캠페인명
    UPPER_CMPGN_BASE AS
    (
        SELECT
            U.CMPGN_CD::VARCHAR AS UPPER_CMPGN_CD,
            MAX(U.CMPGN_NM) AS UPPER_CMPGN_NM
    
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG AS U
    
        GROUP BY
            U.CMPGN_CD::VARCHAR
    ),
    
    -- 9-4. 상위 캠페인 표시 순번
    UPPER_CMPGN_DIM AS
    (
        SELECT
            U.UPPER_CMPGN_CD,
            U.UPPER_CMPGN_NM,
    
            DENSE_RANK() OVER
            (
                ORDER BY
                    CASE
                        WHEN U.UPPER_CMPGN_CD = 'Z~'
                            THEN 1
                        ELSE 0
                    END,
    
                    CASE
                        WHEN TRY_TO_NUMBER(U.UPPER_CMPGN_CD) IS NULL
                            THEN 1
                        ELSE 0
                    END,
    
                    TRY_TO_NUMBER(U.UPPER_CMPGN_CD),
    
                    U.UPPER_CMPGN_CD
            ) AS SORT_ORDR
    
        FROM UPPER_CMPGN_BASE AS U
    ),
    
    -- 9-5. 법인구분
    CPR_DIM AS
    (
        SELECT
            D.DTL_CD_ID::VARCHAR AS CPR_DIV_CD,
            MAX(D.DTL_CD_NM) AS CPR_DIV_NM
        FROM 
            GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD AS D
        WHERE D.CD_ID = 'CM019'
        GROUP BY
            D.DTL_CD_ID::VARCHAR
    ),
    
    -- 9-6. 후원사업 약칭
    ABRV_DIM AS
    (
        SELECT
            D.DTL_CD_ID::VARCHAR AS SPNSR_BSNS_ABRV_CD,
            MAX(D.DTL_CD_NM) AS SPNSR_BSNS_GRP_NM
        FROM 
            GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD AS D
        WHERE 
            D.CD_ID = 'CM003'
        GROUP BY
            D.DTL_CD_ID::VARCHAR
    ),
    -- 10. 최종 출력
    RESULT AS (
        SELECT
            '실적' AS DATA_TYPE_NM,
            LEFT(A.STRD_MT, 4) AS YEAR, 
            CASE 
                WHEN A.UPPER_CMPGN_CD IN (
                    'U1255', 'U1256', 'U1257', 'U1197', 'U1198',
                    'U1199', 'U1261'
                ) THEN '교육기관'
                WHEN A.UPPER_CMPGN_CD IN (
                    'U0892', 'U0897', 'U1105', 'U1106', 'U1107',
                    'U1204', 'U1263', 'U1208', 'U1104', 'U0243',
                    'U1265', 'U1287', 'U0893'
                ) THEN '지역사회'
                ELSE A.UPPER_CMPGN_CD
            END AS DEPT_DIV_NM,
            CASE A.NEW_OLD_DIV_CD
                WHEN '1' THEN '신규'
                WHEN '2' THEN '기존'
                ELSE '없음'
            END AS NEW_EXST_DIV_NM,
            CASE
                WHEN B.SPNSR_BSNS_GRP_NM = '해외구호'
                    THEN '해외프로젝트'
                WHEN B.SPNSR_BSNS_GRP_NM = '국내' OR B.SPNSR_BSNS_GRP_NM = '결연'
                    THEN B.SPNSR_BSNS_GRP_NM
                ELSE '기타'
            END AS SPNSR_BSNS_GRP_NM,
            SUM(A.WJXBFS1) AS VALUE
        FROM REPORT_AGG AS A
            LEFT JOIN DEPT_DIM AS D ON A.DEPT_ID = D.DEPT_ID
            LEFT JOIN DEPT_HIERARCHY AS H ON A.DEPT_ID = H.SOURCE_DEPT_ID
            LEFT JOIN UPPER_CMPGN_DIM AS U ON A.UPPER_CMPGN_CD = U.UPPER_CMPGN_CD
            LEFT JOIN ABRV_DIM AS B ON A.SPNSR_BSNS_ABRV_CD = B.SPNSR_BSNS_ABRV_CD
            LEFT JOIN CPR_DIM AS C ON A.CPR_DIV_CD = C.CPR_DIV_CD
        WHERE 
            A.CPR_DIV_CD = 'I'
        GROUP BY 
            A.STRD_MT,
            CASE 
                WHEN A.UPPER_CMPGN_CD IN (
                    'U1255', 'U1256', 'U1257', 'U1197', 'U1198',
                    'U1199', 'U1261'
                ) THEN '교육기관'
                WHEN A.UPPER_CMPGN_CD IN (
                    'U0892', 'U0897', 'U1105', 'U1106', 'U1107',
                    'U1204', 'U1263', 'U1208', 'U1104', 'U0243',
                    'U1265', 'U1287', 'U0893'
                ) THEN '지역사회'
                ELSE A.UPPER_CMPGN_CD
            END,
            CASE A.NEW_OLD_DIV_CD
                WHEN '1' THEN '신규'
                WHEN '2' THEN '기존'
                ELSE '없음'
            END,
        
            CASE
                WHEN B.SPNSR_BSNS_GRP_NM = '해외구호'
                    THEN '해외프로젝트'
                WHEN B.SPNSR_BSNS_GRP_NM = '국내' OR B.SPNSR_BSNS_GRP_NM = '결연'
                    THEN B.SPNSR_BSNS_GRP_NM
                ELSE '기타'
            END
        ORDER BY
            CASE 
                WHEN A.UPPER_CMPGN_CD IN (
                    'U1255', 'U1256', 'U1257', 'U1197', 'U1198',
                    'U1199', 'U1261' 
                ) THEN '교육기관'
                WHEN A.UPPER_CMPGN_CD IN (
                    'U0892', 'U0897', 'U1105', 'U1106', 'U1107',
                    'U1204', 'U1263', 'U1208', 'U1104', 'U0243',
                    'U1265',  'U1287', 'U0893'
                ) THEN '지역사회'
                ELSE A.UPPER_CMPGN_CD
            END,
            CASE A.NEW_OLD_DIV_CD
                WHEN '1' THEN '신규'
                WHEN '2' THEN '기존'
                ELSE '없음'
            END,
            CASE
                WHEN B.SPNSR_BSNS_GRP_NM = '해외구호' 
                    THEN '해외프로젝트'
                WHEN B.SPNSR_BSNS_GRP_NM = '국내' OR B.SPNSR_BSNS_GRP_NM = '결연' 
                    THEN B.SPNSR_BSNS_GRP_NM
                ELSE '기타'
            END,
        A.STRD_MT
    ) 
    SELECT * FROM RESULT;
    UPDATE_SQL := 
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
           AND T.DEPT_DIV_NM IN (''교육기관'', ''지역사회'')';
    EXECUTE IMMEDIATE :UPDATE_SQL;
    RETURN 'SUCCESS: ' || :FROM_MT;
END;
$$;