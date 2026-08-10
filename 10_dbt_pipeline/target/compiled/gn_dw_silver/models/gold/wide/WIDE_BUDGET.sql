-- WIDE_BUDGET: 예산 팩트(FBD) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.9)
-- Co-authored with CoCo
-- ⚠️ FACT_BUDGET 는 편성/집행만 적재. FUNDRAISING_COST(E-1)·AD_COST(E-4) 원천부재로 현재 NULL(외부 입고 대기).
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.PLAN_BUDGET_MONTH, f.PLAN_BUDGET_YEAR,
    f.EXEC_BUDGET_ERP, f.EXEC_BUDGET_EST,
    f.FUNDRAISING_COST, f.AD_COST,
    f.DW_SOURCE_SYSTEM,
    o.CORP as ORG_CORP, o.DIVISION as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT, o.TEAM as ORG_TEAM,
    bi.BUDGET_ITEM_NAME as BUDGET_ITEM_NAME, bi.BUDGET_CATEGORY as BUDGET_CATEGORY,
    c.CAMPAIGN_BK as CAMPAIGN_BK, c.BRAND as CAMPAIGN_BRAND, c.CAMPAIGN_NAME as CAMPAIGN_NAME,
    s.SPONSORSHIP_BK as SPONSORSHIP_BK, s.SPONSORSHIP_NAME as SPONSORSHIP_NAME
from GN_DW.GOLD.FACT_BUDGET f
left join GN_DW.GOLD.DIM_ORG         o  on f.ORG_SK         = o.ORG_SK
left join GN_DW.GOLD.DIM_BUDGET_ITEM bi on f.BUDGET_ITEM_SK = bi.BUDGET_ITEM_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c  on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s  on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK