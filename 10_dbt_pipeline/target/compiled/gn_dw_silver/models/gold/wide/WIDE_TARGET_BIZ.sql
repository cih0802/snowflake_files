-- WIDE_TARGET_BIZ: 사업목표 팩트(FTG_B) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.4)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.ANNUAL_GOAL_CNT, f.SUPP_GOAL_CNT,
    f.ANNUAL_CUM_GOAL_CNT, f.SUPP_CUM_GOAL_CNT,
    f.DW_SOURCE_SYSTEM,
    o.CORP       as ORG_CORP,
    o.DIVISION   as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT,
    o.TEAM       as ORG_TEAM,
    s.SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME,
    c.CAMPAIGN_BK,
    c.BRAND      as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME
from GN_DW.GOLD.FACT_TARGET_BIZ f
left join GN_DW.GOLD.DIM_ORG         o on f.ORG_SK = o.ORG_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK = c.CAMPAIGN_SK