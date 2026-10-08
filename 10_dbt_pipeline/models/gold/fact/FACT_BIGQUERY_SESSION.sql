-- FACT_BIGQUERY_SESSION: GA4 세션 팩트 (1행 = 1일 × 1세션) · 🆕 [2026-10-08 O213-F Y3-F]
-- Co-authored with CoCo
-- grain: DATE_SK × BIGQUERY_SESSION_KEY  (원천 SILVER.BIGQUERY_SESSION 과 1:1)
-- 왜 FACT_BIGQUERY_BEHAVIOR 와 분리했나 — 그쪽 grain(일×회원×이벤트×소스×기기×페이지)에 세션 속성 25축을
--   넣으면 group by 가 깨진다(O45 선례). 🔴🔴 두 팩트를 **한 표에 합산하지 마라**(같은 원천 · 다른 grain).
--   세션수는 두 팩트가 같은 정의(USER_PSEUDO_ID ∥ GA_SESSION_ID 고유)지만 이쪽은 EP_GA_SESSION_ID 결측 이벤트를 뺀다.
-- 🔴 세션은 일자별로 나뉜다(자정 경계 세션 = 2행) ⇒ 기간 세션수는 COUNT(*) 가 아니라
--    COUNT(DISTINCT BIGQUERY_SESSION_KEY) 로 센다(SV 지표가 그렇게 정의한다).
-- IDENTITY_SK = FACT_BIGQUERY_BEHAVIOR 와 같은 결선(IDENTITY_MEMBER_XREF → DIM_MEMBER_IDENTITY · 미매칭 0).
-- 🔴 범위 재적재 — `macros/gold_fact_purge.sql` RANGED_FACTS 등재 · 이 파일에 pre_hook 금지.
{{ config(
    tags=['gold_ready']
) }}

with s as (
    select * from {{ ref('BIGQUERY_SESSION') }}
    where {{ bigquery_range_predicate('EVENT_DT') }}
),
xref as (
    select USER_PSEUDO_ID, MEMBER_DK
    from {{ ref('IDENTITY_MEMBER_XREF') }}
    where MEMBER_DK is not null
    qualify row_number() over (partition by USER_PSEUDO_ID order by MEMBER_DK) = 1
)

select
    COALESCE({{ date_sk('s.EVENT_DT') }}, 0)   as DATE_SK,
    COALESCE(dmi.IDENTITY_SK, 0)               as IDENTITY_SK,
    s.BIGQUERY_SESSION_KEY,
    s.USER_PSEUDO_ID,
    s.BIGQUERY_SESSION_NUMBER,
    s.SESSION_START_TS,
    s.PLATFORM, s.DEVICE_CATEGORY, s.DEVICE_OPERATING_SYSTEM, s.DEVICE_WEB_INFO_BROWSER,
    s.DEVICE_LANGUAGE, s.DEVICE_MOBILE_BRAND_NAME, s.DEVICE_WEB_INFO_HOSTNAME,
    s.GEO_CONTINENT, s.GEO_SUB_CONTINENT, s.GEO_COUNTRY, s.GEO_METRO,
    s.TS_SOURCE, s.TS_MEDIUM, s.CTS_MANUAL_MEDIUM, s.EP_MEDIUM,
    s.STSLC_CRC_DEFAULT_CHANNEL_GROUP, s.STSLC_CRC_PRIMARY_CHANNEL_GROUP, s.STSLC_CRC_SOURCE_PLATFORM,
    s.STSLC_GAC_CAMPAIGN_NAME, s.STSLC_GAC_AD_GROUP_NAME,
    s.UP_MEMBER_TYPE, s.UP_DONOR_TYPE, s.UP_DONATION_TYPE, s.UP_BIZ_TYPE, s.UP_LOGIN_STATUS,
    s.EP_PAYMENT_TYPE,
    s.EVENT_CNT,
    s.PAGE_VIEW_CNT,
    IFF(s.IS_ENGAGED, 1, 0)                    as ENGAGED_FLAG,
    s.ENGAGEMENT_TIME_MSEC,
    {{ gold_meta('BIGQUERY') }}
from s
left join xref x on x.USER_PSEUDO_ID = s.USER_PSEUDO_ID
left join {{ ref('DIM_MEMBER_IDENTITY') }} dmi on dmi.MEMBER_DK = x.MEMBER_DK
