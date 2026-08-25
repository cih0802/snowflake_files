-- WIDE_GA_BEHAVIOR: GA 행동 팩트(FGA) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.6)
-- Co-authored with CoCo
-- 2026-07-15: DIM_MEMBER_IDENTITY 활성화 → IDENTITY_* 4컬럼 실조인 복원(f.IDENTITY_SK = DIM_MEMBER_IDENTITY.IDENTITY_SK).
--    ⚠️[G-5 재확인] 현재 GA4 1일 샤드 기반(회원 매칭 커버리지 ~4.2%). 전기간 입고 시 재실행·재검증 필요(문서50 G-5 게이트).
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).
{{ config(
    materialized='gn_view_commented'
) }}

select
    f.DATE_SK, f.PAGE_PATH, f.PAGE_LOCATION,
    f.VISITS, f.EVENT_CNT, f.VIEW_CNT, f.SESSION_CNT, f.ENGAGED_SESSIONS,
    f.SCROLL_DEPTH, f.ACTIVE_USERS, f.TOTAL_USERS,
    f.AVG_SESSION_DURATION, f.BOUNCE_RATE, f.ENGAGEMENT_RATE,
    f.AVG_ENGAGEMENT_TIME_PER_SESSION,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    -- DIM_MEMBER_IDENTITY 활성(2026-07-15) → 실제 조인. ⚠️[G-5] GA4 1일 기반·커버리지 ~4.2%, 전기간 입고 시 재검증(문서50)
    mi.MEMBER_DK          as IDENTITY_MEMBER_DK,
    mi.MEMBER_NO          as IDENTITY_MEMBER_NO,
    mi.MEMNUM             as IDENTITY_MEMNUM,
    mi.GA_MEMBER_ID       as IDENTITY_GA_MEMBER_ID,
    ge.EVENT_CATEGORY     as GA_EVENT_CATEGORY,
    ge.EVENT_LABEL        as GA_EVENT_LABEL,
    ge.EVENT_ACTION       as GA_EVENT_ACTION,
    gs.UTM_SOURCE         as GA_UTM_SOURCE,
    gs.UTM_MEDIUM         as GA_UTM_MEDIUM,
    gs.UTM_CONTENT        as GA_UTM_CONTENT,
    gs.UTM_TERM           as GA_UTM_TERM,
    gs.SOURCE_MEDIUM      as GA_SOURCE_MEDIUM,
    dv.DEVICE_TYPE        as DEVICE_TYPE,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME
from {{ ref('FACT_GA_BEHAVIOR') }} f
left join {{ ref('DIM_DATE') }}      d  on f.DATE_SK      = d.DATE_SK
left join {{ ref('DIM_GA_EVENT') }}  ge on f.GA_EVENT_SK  = ge.GA_EVENT_SK
left join {{ ref('DIM_GA_SOURCE') }} gs on f.GA_SOURCE_SK = gs.GA_SOURCE_SK
left join {{ ref('DIM_DEVICE') }}    dv on f.DEVICE_SK    = dv.DEVICE_SK
left join {{ ref('DIM_CAMPAIGN') }}  c  on f.CAMPAIGN_SK  = c.CAMPAIGN_SK
left join {{ ref('DIM_MEMBER_IDENTITY') }} mi on f.IDENTITY_SK = mi.IDENTITY_SK
