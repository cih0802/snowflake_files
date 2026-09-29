-- WIDE_TARGET_BIZ: 사업목표 팩트(FTG_B) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.4)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).
{{ config(
    materialized='gn_view_commented'
) }}

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
    c.CAMPAIGN_NAME,
    -- 🆕 [2026-09-29 O188] 이중계상 가드 전파 — 🔴 GOAL_TYPE_NM 으로 필터하지 않으면 합계가 약 2배(N-24)
    f.GOAL_TYPE_NM,
    f.CPR_DIV_NM,
    -- 🆕 [2026-09-29 O188-E] 조직 경로 + 원천 이름 degen 5축(SV_TARGET_BIZ 노출용 · yml columns 순서 동기)
    o.ORG_PATH,
    f.SRC_TEAM_NM,
    f.SRC_SPONSOR_BIZ_NM,
    f.NEW_OLD_DIV_NM,
    f.ORG_DIV_NM,
    f.DTL_DIV_NM
from {{ ref('FACT_TARGET_PROJECT') }} f
left join {{ ref('DIM_ORG') }}         o on f.ORG_SK = o.ORG_SK
left join {{ ref('DIM_SPONSORSHIP') }} s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join {{ ref('DIM_CAMPAIGN') }}    c on f.CAMPAIGN_SK = c.CAMPAIGN_SK
