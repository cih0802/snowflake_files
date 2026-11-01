-- 31. 공8 「GA 개발단가」 정의 확정 — 쿼리 근거 (문서 30 의 수치 전부를 재현한다)
-- Co-authored with CoCo · 2026-09-29 O188 · 계정 xf98254 · 읽기 전용(변경 없음)
-- 🔄 [O188-B] 승계됨 → 31_공8및미회신29건_쿼리근거.sql ([G8-1]~[G8-3] = GA4 분모 대조 추가)

-- [Q1] 원천 기간 — YEAR/MONTH/DAY 원값도 2026-06~09 만 존재(DATE 파싱 문제가 아니다)
SELECT YEAR, MONTH, COUNT(*) AS n, COUNT(DISTINCT DAY) AS days,
       COUNT_IF("DATE" = '1970-01-01') AS epoch_rows
FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS
GROUP BY 1, 2
ORDER BY 1, 2;
-- 실측: 2026-6 9,018 · 7 10,616 · 8 3,130 · 9 6,284 (합 29,048) · 이전 연월 0행

-- [Q2] 원천 테이블 이력 — 09-27 19:08 재생성본 1개뿐(드롭된 이전 버전 없음)
SHOW TABLES HISTORY LIKE 'DGT_AD_CMPGN_DTLS' IN SCHEMA GN_DW.BRONZE_AGENCY;

-- [Q3] 원천 「개발단가」의 산식 판정 — 분모가 CONV_VU_CNT 임을 행 단위로 확인
WITH b AS (
    SELECT * FROM GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS WHERE DVLP_UNIT_PRICE > 0
)
SELECT COUNT(*) AS n,
       AVG(IFF(ABS(DVLP_UNIT_PRICE - AD_COST / NULLIF(CONV_VU_CNT, 0)) < 1, 1, 0))     AS eq_cost_over_conv_vu,
       AVG(IFF(ABS(DVLP_UNIT_PRICE - AD_COST / NULLIF(SPNSER_MBER_CNT, 0)) < 1, 1, 0)) AS eq_cost_over_spnser
FROM b;
-- 실측: n 6,226 · eq_cost_over_conv_vu 0.999036 · eq_cost_over_spnser 0.129778

-- [Q4] 공8 산출(GOLD · SV_AD base) — DIGITAL 전용, 방송 2종은 분모 NULL
SELECT AD_SOURCE_TYPE,
       COUNT(*)                                             AS n,
       SUM(AD_COST)                                         AS ga_ad_cost,
       SUM(AGENCY_CONV_CNT)                                 AS ga_dev_cnt,
       SUM(AD_COST) / NULLIF(SUM(AGENCY_CONV_CNT), 0)       AS ga_dev_unit_price,
       SUM(AD_COST) / NULLIF(SUM(AGENCY_CONV_MEMBERS), 0)   AS per_member_not_gong8,
       COUNT(CRM_DEV_CNT)                                   AS crm_dev_rows
FROM GN_DW.GOLD.WIDE_AD_COMBINED
GROUP BY 1;
-- 실측: DIGITAL 29,048 · 3,803,364,381.90 · 38,847.261 · 97,905.60 · 221,010.19 · 0
--       VIDEO·REBROADCAST = ga_dev_cnt NULL · crm_dev_rows 0

-- [Q5] 월별 추이 — 공8 시계열
SELECT AD_YEAR, AD_MONTH,
       SUM(AD_COST) / NULLIF(SUM(CONV_UNIT_CNT), 0) AS ga_dev_unit_price
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE
WHERE AD_SOURCE_TYPE = 'DIGITAL'
GROUP BY 1, 2
ORDER BY 1, 2;
-- 실측: 2026-06 104,333 · 07 107,226 · 08 72,797 · 09 89,225

-- [Q6] 공8 정의 원문(정본 = 90_provided_definition/02_지표사전 공통.md:33)
--   | 8 | 개발 | GA 개발단가 | 투입 GA광고비 대비 GA개발(건) | GA 광고비 / GA 개발 건 |
--   비교: 32행 | 7 | 개발 | CRM 개발단가 | 투입 광고비 대비 CRM 개발(건) | 광고비 / CRM 개발 건 |
