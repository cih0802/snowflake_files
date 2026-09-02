-- WIDE_AD_PERFORMANCE: 광고 성과 **코어** 팩트(FAD) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.7)
-- Co-authored with CoCo
-- ⚠️ [2026-07-28 순서9-I DEC-8] 코어에서 위성으로 이관된 방송 degen 5종
--    (TIME_BAND·CM_POSITION·RT_TYPE·AD_START_TIME·BROADCAST_DATE)을 본 뷰에서 **제거**했다.
--    본 뷰는 팩트와 1:1 대응 원칙을 지키며 **코어 컬럼만** 평탄화한다.
--    → 방송 고유속성은 `WIDE_AD_BROADCAST` · 디지털은 `WIDE_AD_DIGITAL` · 사례는 `WIDE_AD_BROADCAST_CASE`.
-- ⚠️ 명명 충돌 해소: `AD_SOURCE_TYPE`(코어 degen = 원천 출처축 DIGITAL/VIDEO/REBROADCAST)과
--    `AD_CREATIVE_TYPE`(DIM_AD_CREATIVE 소재 광고유형)은 **다른 개념**이다. 종전 두 컬럼이 모두
--    `AD_TYPE` 이라 혼동 소지가 있었으므로 내용에 맞게 분리 명명했다(소비자 부재 확인 후 적용).
-- ⚠️ CAMPAIGN_SK·AD_CREATIVE_SK 는 여전히 0 스캐폴드(Q10 이름매칭·소재 부분키 대기) → 관련 컬럼 NULL.
--    DEVICE_SK 는 DEC-10 으로 실배선 완료(방송행은 `(해당없음)` 멤버).
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.AD_PERF_DK,
    f.PERF_DATE_SK,
    f.AD_COST, f.IMPRESSIONS, f.CLICKS, f.INBOUND_CALL,
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,
    f.DAY_OF_WEEK, f.WEEK_OF_YEAR,
    f.AD_SOURCE_TYPE,
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
    ac.AD_TYPE            as AD_CREATIVE_TYPE,   -- 소재 광고유형 (≠ AD_SOURCE_TYPE)
    ac.TARGET_GROUP       as AD_TARGET_GROUP,
    dv.DEVICE_TYPE        as DEVICE_TYPE,
    dv.DEVICE_SCOPE_DESC  as DEVICE_SCOPE_DESC
from GN_DW.GOLD.FACT_AD_PERFORMANCE f
left join GN_DW.GOLD.DIM_DATE        d  on f.PERF_DATE_SK   = d.DATE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c  on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_AD_CREATIVE ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
left join GN_DW.GOLD.DIM_DEVICE      dv on f.DEVICE_SK      = dv.DEVICE_SK