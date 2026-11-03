-- 회원통계보고서 대시보드 SQL - Streamlit 앱과 동일 로직 (개발건 = SPNSR_AMT/10000)
-- Co-authored with CoCo

-- ============================================================
-- 공통 CTE: 신규/재후원 + 증액 개발건 산출
-- • 신규(1)/재후원(4): 해지일 필터 + 월합 양수
-- • 증액(2): 회원 월 순액 양수 + RAMT 배분
-- • 개발건 = SUM(SPNSR_AMT) / 10,000
-- • 법인: 사단법인 (CPR_DIV_CD='I')
-- • 신규회원 판정: DVLP_DIV_CD='1' 최초 개발일 기준
-- • 2025년 허수회원 제외: (1846164/03, 1860931/04, 1860972/04, 1721918/10, 1945685/12, 1894701/12)
-- ============================================================

-- 파라미터 (조회 년도/월에 따라 변경)
-- SET YEAR_START = '20260101';
-- SET YEAR_END   = '20261231';
-- SET MONTH_START = '20260601';
-- SET MONTH_END   = '20260630';

-- ============================================================
-- 1-1. 회원개발 현황(당월) - 부서별 개발건
-- ============================================================
WITH new_rejoin_base AS (
    SELECT
        LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
        SUM(A.SPNSR_AMT) OVER (
            PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)
        ) AS MAMT,
        A.SPNSR_NO, A.SPNSR_BSNS_NO, A.OCCRRNC_DE, A.SER_NO,
        A.MBER_NO, A.ACMSLT_DEPT_CD, A.SPNSR_BSNS_ID,
        A.SPNSR_AMT, A.DVLP_DIV_CD, A.MBER_DIV_CD, A.CMPGN_CD
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
        ON A.SPNSR_NO = B.SPNSR_NO AND A.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
        AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231')
            > LEFT(A.OCCRRNC_DE, 6) || '31'
    WHERE A.OCCRRNC_DE BETWEEN '20260101' AND '20261231'
      AND A.DVLP_DIV_CD IN ('1', '4')
),
new_rejoin AS (
    SELECT STRD_MT, SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO,
           MBER_NO, COALESCE(ACMSLT_DEPT_CD, 'Z~') AS DEPT_ID,
           SPNSR_BSNS_ID, DVLP_DIV_CD, SPNSR_AMT, MBER_DIV_CD, CMPGN_CD
    FROM new_rejoin_base
    WHERE MAMT > 0
),
change_base AS (
    SELECT
        LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
        SUM(CASE WHEN A.DVLP_DIV_CD IN ('2','3') THEN A.SPNSR_AMT ELSE 0 END)
            OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS SAMT,
        SUM(A.SPNSR_AMT)
            OVER (PARTITION BY A.MBER_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,
        A.SPNSR_NO, A.SPNSR_BSNS_NO, A.OCCRRNC_DE, A.SER_NO,
        A.MBER_NO, A.ACMSLT_DEPT_CD, A.SPNSR_BSNS_ID,
        A.SPNSR_AMT, A.DVLP_DIV_CD, A.MBER_DIV_CD, A.CMPGN_CD
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
    WHERE A.OCCRRNC_DE BETWEEN '20260101' AND '20261231'
      AND A.DVLP_DIV_CD IN ('2', '3', '5')
),
change_member AS (
    SELECT
        SUM(CASE WHEN C.DVLP_DIV_CD = '3' THEN C.SPNSR_AMT ELSE 0 END)
            OVER (PARTITION BY C.MBER_NO, C.STRD_MT) AS DAMT,
        C.*
    FROM change_base C
    WHERE C.MAMT > 0
      AND ((C.SAMT > 0 AND C.DVLP_DIV_CD = '2') OR (C.SAMT < 0 AND C.DVLP_DIV_CD = '3'))
),
change_running AS (
    SELECT
        SUM(C.SAMT) OVER (
            PARTITION BY C.MBER_NO, C.STRD_MT ORDER BY C.OCCRRNC_DE, C.SER_NO
        ) AS AAMT,
        C.*
    FROM change_member C
    WHERE C.DVLP_DIV_CD = '2'
),
change_alloc AS (
    SELECT
        ROW_NUMBER() OVER (
            PARTITION BY C.STRD_MT, C.SPNSR_NO, C.SPNSR_BSNS_NO ORDER BY C.SER_NO
        ) AS RNUM,
        CASE
            WHEN C.MAMT <= C.SAMT AND C.AAMT + C.DAMT <= C.MAMT THEN C.AAMT + C.DAMT
            WHEN C.MAMT > C.SAMT AND C.AAMT + C.DAMT <= C.SAMT THEN C.AAMT + C.DAMT
            WHEN C.MAMT <= C.SAMT THEN C.MAMT
            ELSE C.SAMT
        END AS RAMT,
        C.*
    FROM change_running C
    WHERE C.AAMT - ABS(C.DAMT) > 0
),
increase AS (
    SELECT STRD_MT, SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO,
           MBER_NO, COALESCE(ACMSLT_DEPT_CD, 'Z~') AS DEPT_ID,
           SPNSR_BSNS_ID, '2' AS DVLP_DIV_CD, RAMT AS SPNSR_AMT,
           MBER_DIV_CD, CMPGN_CD
    FROM change_alloc
    WHERE RNUM = 1
),
transformed AS (
    SELECT * FROM new_rejoin
    UNION ALL
    SELECT * FROM increase
),
dvlp_fact AS (
    SELECT
        T.STRD_MT,
        T.OCCRRNC_DE,
        D.DEPT_NM AS DEPT_NAME,
        T.DVLP_DIV_CD AS DVLP_TYPE,
        T.MBER_NO,
        T.MBER_DIV_CD AS MBER_DIV,
        T.SPNSR_AMT,
        COALESCE(BIZ.CPR_DIV_CD, '0') AS CPR_DIV_CD,
        C.CMPGN_NM AS CAMPAIGN_NAME,
        UC.CMPGN_NM AS UPPER_CAMPAIGN,
        T.CMPGN_CD
    FROM transformed T
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON T.DEPT_ID = D.DEPT_ID
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO BIZ ON T.SPNSR_BSNS_ID = BIZ.SPNSR_BSNS_ID
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG C ON C.CMPGN_CD = T.CMPGN_CD
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG UC ON UC.CMPGN_CD = C.UPPER_CMPGN_CD
    WHERE COALESCE(BIZ.CPR_DIV_CD, '0') = 'I'
),
first_dev AS (
    SELECT MBER_NO, MIN(OCCRRNC_DE) AS FIRST_DEV_DATE
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
    WHERE DVLP_DIV_CD = '1'
    GROUP BY MBER_NO
),
final_data AS (
    SELECT
        f.STRD_MT,
        f.OCCRRNC_DE,
        CASE
            WHEN f.DEPT_NAME IS NULL THEN '시도본부 및 지부'
            WHEN f.DEPT_NAME LIKE '%회원%' THEN '회원참여팀'
            WHEN f.DEPT_NAME IN ('캠페인기획2팀', '소셜펀딩부') THEN '캠페인기획2팀(가두)'
            WHEN f.DEPT_NAME IN ('사회공헌협력팀', 'ESG팀') THEN '사회공헌협력팀'
            WHEN f.DEPT_NAME IN ('매체운영팀', '마케팅기획1팀', '마케팅기획2팀', '컬쳐콘텐츠팀') THEN f.DEPT_NAME
            ELSE '시도본부 및 지부'
        END AS "부서",
        CASE f.DVLP_TYPE WHEN '1' THEN '신규' WHEN '2' THEN '증액' WHEN '4' THEN '재후원' END AS "개발구분",
        CASE WHEN fd.FIRST_DEV_DATE >= '20260101' THEN '신규회원' ELSE '기존회원' END AS "회원구분",
        f.SPNSR_AMT / 10000.0 AS "개발건",
        f.MBER_NO,
        COALESCE(f.UPPER_CAMPAIGN, '미분류') AS "상위캠페인",
        COALESCE(f.CAMPAIGN_NAME, '미분류') AS "캠페인명"
    FROM dvlp_fact f
    LEFT JOIN first_dev fd ON f.MBER_NO = fd.MBER_NO
)

-- 1-1 당월 부서별 개발건
SELECT
    "부서",
    SUM(CASE WHEN "개발구분" = '신규' THEN "개발건" ELSE 0 END) AS "신규",
    SUM(CASE WHEN "개발구분" = '재후원' THEN "개발건" ELSE 0 END) AS "재후원",
    SUM(CASE WHEN "개발구분" = '증액' THEN "개발건" ELSE 0 END) AS "증액",
    SUM("개발건") AS "합계"
FROM final_data
WHERE OCCRRNC_DE BETWEEN '20260601' AND '20260630'
GROUP BY "부서"
ORDER BY
    CASE "부서"
        WHEN '매체운영팀' THEN 1 WHEN '마케팅기획1팀' THEN 2
        WHEN '마케팅기획2팀' THEN 3 WHEN '컬쳐콘텐츠팀' THEN 4
        WHEN '회원참여팀' THEN 5 WHEN '캠페인기획2팀(가두)' THEN 6
        WHEN '사회공헌협력팀' THEN 7 WHEN '시도본부 및 지부' THEN 8
    END;

-- ============================================================
-- 1-2. 회원개발 현황(누계) - 동일 CTE, 기간만 변경
-- WHERE OCCRRNC_DE BETWEEN '20260101' AND '20260630'
-- ============================================================

-- ============================================================
-- 1-3. 회원구분별 현황(당월)
-- 신규회원: 당해년도 최초 신규개발(DVLP_DIV_CD='1') 회원
-- 기존회원: 이전년도 이미 개발 이력 있는 회원 또는 재후원(4)만 있는 회원
-- ============================================================
-- (동일 CTE 사용, final_data에서 필터)
-- SELECT
--     "회원구분" AS "신규기존",
--     CASE
--         WHEN "회원구분" = '기존회원' THEN '기존회원'
--         WHEN "부서" = '시도본부 및 지부' THEN '시도본부 및 지부'
--         ELSE '본부'
--     END AS "본부/지부",
--     SUM(CASE WHEN "개발구분" = '신규' THEN "개발건" ELSE 0 END) AS "신규",
--     SUM(CASE WHEN "개발구분" = '재후원' THEN "개발건" ELSE 0 END) AS "재후원",
--     SUM(CASE WHEN "개발구분" = '증액' THEN "개발건" ELSE 0 END) AS "증액",
--     SUM("개발건") AS "합계"
-- FROM final_data
-- WHERE OCCRRNC_DE BETWEEN '20260601' AND '20260630'
-- GROUP BY "신규기존", "본부/지부"
-- ORDER BY "신규기존", "본부/지부";

-- ============================================================
-- 1-4. 회원구분별 현황(누계) - 1-3과 동일, 기간 변경
-- WHERE OCCRRNC_DE BETWEEN '20260101' AND '20260630'
-- ============================================================

-- ============================================================
-- 1-5. 상위캠페인별 개발 TOP10 (당월 기준)
-- 개발명수 = 상위캠페인별 고유 회원수 (중복 허용)
-- ============================================================
-- (동일 CTE 사용, final_data에서 필터)
-- WITH month_ranked AS (
--     SELECT
--         "상위캠페인",
--         SUM("개발건") AS "당월 개발건",
--         COUNT(DISTINCT MBER_NO) AS "당월 개발명수"
--     FROM final_data
--     WHERE OCCRRNC_DE BETWEEN '20260601' AND '20260630'
--     GROUP BY "상위캠페인"
-- ),
-- ytd_agg AS (
--     SELECT
--         "상위캠페인",
--         SUM("개발건") AS "누계 개발건",
--         COUNT(DISTINCT MBER_NO) AS "누계 개발명수"
--     FROM final_data
--     WHERE OCCRRNC_DE BETWEEN '20260101' AND '20260630'
--     GROUP BY "상위캠페인"
-- ),
-- top10 AS (
--     SELECT *, ROW_NUMBER() OVER (ORDER BY "당월 개발건" DESC) AS rn
--     FROM month_ranked
-- )
-- SELECT
--     t.rn AS "순위",
--     t."상위캠페인",
--     t."당월 개발명수",
--     t."당월 개발건",
--     ROUND(t."당월 개발건" * 100.0 / SUM(t."당월 개발건") OVER (), 1) AS "당월 구성비(%)",
--     y."누계 개발명수",
--     y."누계 개발건",
--     ROUND(y."누계 개발건" * 100.0 / SUM(y."누계 개발건") OVER (), 1) AS "누계 구성비(%)"
-- FROM top10 t
-- LEFT JOIN ytd_agg y ON y."상위캠페인" = t."상위캠페인"
-- WHERE t.rn <= 10
-- ORDER BY t.rn;

-- ============================================================
-- 참고: 수동 조정 사항 (Streamlit 앱에서 후처리)
-- ============================================================
-- 2026년 4월 (당월 + 이후 누계):
--   1-1/1-2: 시도본부 및 지부 신규 -1, 재후원 +1
--   1-3/1-4: 신규회원 본부 신규 +1, 시도본부 신규 -1, 기존회원 신규 -1 재후원 +1
--
-- 2025년 허수회원 제외 (해당 월 기록만):
--   1846164 (202503), 1860931 (202504), 1860972 (202504),
--   1721918 (202510), 1945685 (202512), 1894701 (202512)
