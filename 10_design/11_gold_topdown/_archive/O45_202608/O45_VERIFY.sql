-- ============================================================================
-- O45_VERIFY.sql — dbt build **이후** 사후 검증 관문 (O45)
-- Co-authored with CoCo
-- 🔴 build 가 ERROR=0 으로 끝나도 신규 컬럼이 안 들어갈 수 있다(O40 무증상 폐기 · P82).
--    따라서 「빌드 성공」이 아니라 **값이 들어왔는지**를 여기서 확인한다.
-- ============================================================================
USE ROLE ACCOUNTADMIN; USE WAREHOUSE COMPUTE_WH; USE DATABASE GN_DW;

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-A 회귀 없음 — 기존 팩트·차원 행수 불변
--   기준값(2026-08-06): FME 4,633,105 · FMC 1,585,949 · DIM_CAMPAIGN 36,144 · FAP 243,545
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-A 행수 불변' AS gate,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_EVENT)   AS fme_rows,      -- = 4633105
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_COHORT)  AS fmc_rows,      -- = 1585949
       (SELECT COUNT(*) FROM GOLD.DIM_CAMPAIGN)        AS dim_cmp_rows,  -- = 36144
       (SELECT COUNT(*) FROM GOLD.FACT_AD_PERFORMANCE) AS fap_rows;      -- = 243545

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-B 신규 컬럼에 값이 실제로 들어왔는가 (P82 — 이것이 핵심 관문)
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-B 값 주입' AS gate,
       (SELECT COUNT_IF(SPONSORSHIP_SK <> 0) FROM GOLD.FACT_MEMBER_EVENT)      AS fme_spb_nonzero,
       (SELECT COUNT_IF(ACQ_ORG_SK <> 0) FROM GOLD.FACT_MEMBER_COHORT)         AS fmc_acq_org_nonzero,
       (SELECT COUNT_IF(ACQ_SPONSORSHIP_SK <> 0) FROM GOLD.FACT_MEMBER_COHORT) AS fmc_acq_spb_nonzero,
       (SELECT COUNT_IF(MKTG_CAMPAIGN_SK <> 0) FROM GOLD.DIM_CAMPAIGN)         AS dim_cmp_mktg_nonzero,
       (SELECT COUNT_IF(MKTG_CAMPAIGN_SK <> 0) FROM GOLD.FACT_AD_PERFORMANCE)  AS fap_mktg_nonzero;
-- 기대(실측 근거):
--   fme_spb_nonzero        ≈ 3,594,843 (개발행 전량 — 중단행은 0 유지가 정상)
--   fmc_acq_org_nonzero    ≈ 1,585,922 (99.9999%)
--   fmc_acq_spb_nonzero    ≈ 1,585,923 (100%)
--   dim_cmp_mktg_nonzero   ≈    33,915 (93.8%)
--   fap_mktg_nonzero       ≈   218,402 (89.7%)
-- 🔴 어느 하나라도 0 이면 **컬럼이 조용히 폐기된 것**이다 — on_schema_change 를 확인할 것.

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-C 팬아웃 없음 — 조립의 전제 (이게 깨지면 모든 집계가 틀린다)
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-C 팬아웃' AS gate,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_COHORT)                       AS fmc_rows,
       (SELECT COUNT(DISTINCT MEMBER_DK) FROM GOLD.FACT_MEMBER_COHORT)      AS fmc_members,  -- 위와 같아야 한다
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_MONTHLY f
          LEFT JOIN GOLD.DIM_MEMBER_ACQUISITION a ON a.MEMBER_DK=f.MEMBER_DK) AS fmm_joined,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_MONTHLY)                      AS fmm_rows;
-- 기대: fmc_rows = fmc_members (1행/회원) · fmm_joined = fmm_rows (LEFT JOIN 팬아웃 0)

SELECT 'GATE-C2 광고 팬아웃' AS gate,
       (SELECT COUNT(*) FROM GOLD.FACT_AD_PERFORMANCE f
          LEFT JOIN GOLD.DIM_MARKETING_CAMPAIGN m ON m.MKTG_CAMPAIGN_SK=f.MKTG_CAMPAIGN_SK) AS joined,
       (SELECT COUNT(*) FROM GOLD.FACT_AD_PERFORMANCE) AS base;
-- 기대: joined = base = 243,545

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-D 회비 팩트 정합 — FMM 과 총계가 일치해야 한다
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-D 회비 정합' AS gate,
       (SELECT SUM(BILLED_AMT) FROM GOLD.FACT_MEMBER_FEE)              AS fmf_billed,
       (SELECT SUM(BILLED_AMT) FROM GOLD.FACT_MEMBER_MONTHLY)          AS fmm_billed,
       (SELECT SUM(RQEST_AMT)  FROM SILVER.CRM_PAYMENT_BILLING)        AS silver_billed,
       (SELECT SUM(PAID_FEE_BILLABLE) FROM GOLD.FACT_MEMBER_FEE)       AS fmf_paid_billable,
       (SELECT SUM(PAID_FEE_BILLABLE) FROM GOLD.FACT_MEMBER_MONTHLY)   AS fmm_paid_billable,
       (SELECT SUM(UNPAID_BILLED_AMT) FROM GOLD.FACT_MEMBER_FEE)       AS fmf_unpaid,
       (SELECT SUM(UNPAID_BILLED_AMT) FROM GOLD.FACT_MEMBER_MONTHLY)   AS fmm_unpaid;
-- 기대: fmf_billed = fmm_billed = silver_billed = 891,959,790,888
--       fmf_paid_billable = fmm_paid_billable = 768,800,286,349
--       fmf_unpaid        = fmm_unpaid        = 122,621,758,323
-- 🔴 어긋나면 **어느 쪽이 맞는지 아무도 모르게 된다** — 반드시 원인 규명 후 배포할 것.
--    (종전 실측에서 납입은 FMM 이 SILVER 대비 0.004% 낮았다 = 월키 클램프 추정 → 이번에 규명)

SELECT 'GATE-D2 grain 유일성' AS gate, COUNT(*) AS dup_groups
FROM (
    SELECT MEMBER_DK, MONTH_KEY, SPONSORSHIP_SK, PAYMENT_SK, FEE_DIV_CD, PAYMENT_TYPE, SETLE_CD
    FROM GOLD.FACT_MEMBER_FEE
    GROUP BY 1,2,3,4,5,6,7 HAVING COUNT(*) > 1
);
-- 기대: 0 (grain 이 선언대로 유일해야 한다)

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-E 고아 FK 없음 (센티넬 라우팅이 제대로 걸렸는가)
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-E 고아 FK' AS gate,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_FEE f
          LEFT JOIN GOLD.DIM_SPONSORSHIP d ON d.SPONSORSHIP_SK=f.SPONSORSHIP_SK
         WHERE d.SPONSORSHIP_SK IS NULL)                                AS fmf_orphan_spb,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_FEE f
          LEFT JOIN GOLD.DIM_PAYMENT d ON d.PAYMENT_SK=f.PAYMENT_SK
         WHERE d.PAYMENT_SK IS NULL)                                    AS fmf_orphan_pay,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_COHORT c
          LEFT JOIN GOLD.DIM_ORG d ON d.ORG_SK=c.ACQ_ORG_SK
         WHERE d.ORG_SK IS NULL)                                        AS fmc_orphan_org,
       (SELECT COUNT(*) FROM GOLD.FACT_AD_PERFORMANCE f
          LEFT JOIN GOLD.DIM_MARKETING_CAMPAIGN d ON d.MKTG_CAMPAIGN_SK=f.MKTG_CAMPAIGN_SK
         WHERE d.MKTG_CAMPAIGN_SK IS NULL)                              AS fap_orphan_mktg;
-- 기대: 전부 0

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-F 목표 실증 — 「마케팅캠페인 grain 개발단가」가 실제로 나오는가
--   O45 의 존재 이유다. 이 값이 안 나오면 축을 만든 의미가 없다.
-- ────────────────────────────────────────────────────────────────────────────
WITH ad AS (
    SELECT f.MKTG_CAMPAIGN_SK, SUM(f.AD_COST) AS ad_cost, COUNT(*) AS ad_rows
    FROM GOLD.FACT_AD_PERFORMANCE f WHERE f.MKTG_CAMPAIGN_SK <> 0 GROUP BY 1
),
dev AS (
    SELECT c.MKTG_CAMPAIGN_SK, SUM(e.DEV_CNT) AS dev_cnt
    FROM GOLD.FACT_MEMBER_EVENT e
    JOIN GOLD.DIM_CAMPAIGN c ON c.CAMPAIGN_SK = e.CAMPAIGN_SK
    WHERE e.DVLP_DIV_CD IN ('1','2','4') AND c.MKTG_CAMPAIGN_SK <> 0
    GROUP BY 1
)
SELECT 'GATE-F 개발단가' AS gate,
       COUNT(*)                                          AS matched_campaigns,  -- ≈ 79
       SUM(a.ad_rows)                                    AS ad_rows,            -- ≈ 216,481 (폭발 0)
       SUM(a.ad_cost)                                    AS ad_cost,            -- ≈ 34,209,625,719
       SUM(d.dev_cnt)                                    AS dev_cnt,            -- ≈ 463,279
       ROUND(SUM(a.ad_cost)/NULLIF(SUM(d.dev_cnt),0))     AS dev_unit_price      -- ≈ 73,842
FROM ad a JOIN dev d ON d.MKTG_CAMPAIGN_SK = a.MKTG_CAMPAIGN_SK;

-- ────────────────────────────────────────────────────────────────────────────
-- GATE-G 획득 귀속 축이 실제로 분해되는가 (O44 차단 41필드의 해소 실증)
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-G 획득귀속 분해' AS gate,
       COUNT(DISTINCT a.ACQ_BRAND)                  AS brands,        -- > 1 이어야 한다
       COUNT(DISTINCT a.ACQ_PARENT_CAMPAIGN_NAME)   AS parents,
       COUNT(DISTINCT a.ACQ_PROMO_METHOD_NAME)      AS promos,
       COUNT(DISTINCT a.ACQ_DEPARTMENT)             AS departments,
       COUNT(DISTINCT a.ACQ_SPONSORSHIP_NAME)       AS sponsorships,
       COUNT_IF(a.MEMBER_DK IS NULL)                AS unmatched_rows -- ≈ 1.61% (LEFT JOIN 정상)
FROM GOLD.FACT_MEMBER_MONTHLY f
LEFT JOIN GOLD.DIM_MEMBER_ACQUISITION a ON a.MEMBER_DK = f.MEMBER_DK;
-- 🔴 brands/departments/sponsorships 가 1 이하로 나오면 축이 죽은 것이다.
