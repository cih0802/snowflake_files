
  create or replace   view GN_DW.GOLD.WIDE_AD_PERFORMANCE
  
   as (
    -- WIDE_AD_PERFORMANCE: 광고 성과 팩트(FAD) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.7)
-- Co-authored with CoCo
-- ⚠️ FACT_AD_PERFORMANCE 는 스캐폴드(measure/날짜만, CAMPAIGN_SK=0·차원FK 미해소). 캠페인 매칭(Q10)·GA전환정의(O5) 회신 전 부분 공백 반영.


select
    f.PERF_DATE_SK,
    f.AD_COST, f.IMPRESSIONS, f.CLICKS, f.INBOUND_CALL,
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,
    f.DAY_OF_WEEK, f.WEEK_OF_YEAR, f.TIME_BAND,
    f.CM_POSITION, f.RT_TYPE, f.AD_START_TIME, f.BROADCAST_DATE,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE           as PERF_FULL_DATE,
    d.YEAR                as PERF_YEAR,
    d.MONTH               as PERF_MONTH,
    d.QUARTER             as PERF_QUARTER,
    d.IS_HOLIDAY          as PERF_IS_HOLIDAY,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.PARENT_CAMPAIGN     as CAMPAIGN_PARENT,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    c.PROMO_METHOD        as CAMPAIGN_PROMO_METHOD,
    c.CAMPAIGN_TYPE       as CAMPAIGN_TYPE,
    ac.AD_CREATIVE_BK     as AD_CREATIVE_BK,
    ac.MEDIA_NAME         as AD_MEDIA_NAME,
    ac.PLATFORM           as AD_PLATFORM,
    ac.PLATFORM_TYPE      as AD_PLATFORM_TYPE,
    ac.CREATIVE           as AD_CREATIVE,
    ac.AD_TYPE            as AD_TYPE,
    ac.TARGET_GROUP       as AD_TARGET_GROUP,
    dv.DEVICE_TYPE        as DEVICE_TYPE
from GN_DW.GOLD.FACT_AD_PERFORMANCE f
left join GN_DW.GOLD.DIM_DATE        d  on f.PERF_DATE_SK   = d.DATE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c  on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_AD_CREATIVE ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
left join GN_DW.GOLD.DIM_DEVICE      dv on f.DEVICE_SK      = dv.DEVICE_SK
  );

