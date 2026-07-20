
  create or replace   view GN_DW.GOLD.WIDE_MEMBER_EVENT
  
   as (
    -- WIDE_MEMBER_EVENT: 회원 이벤트 팩트(FME) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.2)
-- Co-authored with CoCo


select
    f.DATE_SK, f.MEMBER_DK, f.EVENT_TYPE,
    f.DEV_CNT, f.DEV_MEMBERS,
    f.STOP_CNT, f.STOP_MEMBERS,
    f.UNPAID_STOP_CNT, f.UNPAID_STOP_MEMBERS,
    f.JOIN_DATE, f.STOP_DATE, f.STOP_REASON, f.STOP_CHANNEL, f.NEW_EXISTING_FLAG,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.QUARTER, d.IS_HOLIDAY,
    m.GENDER              as MEMBER_GENDER,
    m.REGION              as MEMBER_REGION,
    m.AGE_BAND            as MEMBER_AGE_BAND,
    m.MEMBER_STATUS       as MEMBER_STATUS,
    m.MEMBER_TYPE         as MEMBER_TYPE,
    m.ENROLL_PATH         as MEMBER_ENROLL_PATH,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME,
    o.CORP                as ORG_CORP,
    o.DIVISION            as ORG_DIVISION,
    o.DEPARTMENT          as ORG_DEPARTMENT,
    o.TEAM                as ORG_TEAM,
    r.REASON_CODE         as REASON_CODE,
    r.REASON_NAME         as REASON_NAME,
    r.REASON_TYPE         as REASON_TYPE
from GN_DW.GOLD.FACT_MEMBER_EVENT f
left join GN_DW.GOLD.DIM_DATE d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, GENDER, REGION, AGE_BAND, MEMBER_STATUS, MEMBER_TYPE, ENROLL_PATH
    from GN_DW.GOLD.DIM_MEMBER
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_ORG         o on f.ORG_SK         = o.ORG_SK
left join GN_DW.GOLD.DIM_REASON      r on f.REASON_SK      = r.REASON_SK
  );

