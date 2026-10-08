-- BIGQUERY_SESSION: GA4 세션 속성 (1행 = 1일 × 1세션) · 🆕 [2026-10-08 O213-F Y3-F]
-- Co-authored with CoCo
--
-- 왜 신설했나 — 현업 질문 「후원자유형·회원유형·국가·브라우저별 방문은?」에 답할 축이 GOLD 에 없었다.
--   BIGQUERY_BASIC 은 기기·채널 일부만 승계하고 user_property(UP_*)·지리 상위·유입 원천(TS_*)·
--   cross-channel 주채널 등 25축을 버린다(O213 Y1 lineage NONE 실측).
--   FACT_BIGQUERY_BEHAVIOR(일×회원×이벤트×소스×기기×페이지) group by 에 25축을 넣으면 grain 이 깨진다
--   ⇒ O45 선례(grain 이 다르면 팩트 분리)로 세션 grain 을 따로 둔다.
--   실측 근거: 세션 1,224,849 · 세션×대표 축 4종 조합 1,235,517(+0.9%) ⇒ 축들은 사실상 세션 속성이다.
--
-- 🔴 grain = EVENT_DT × USER_PSEUDO_ID × BIGQUERY_SESSION_ID(EP_GA_SESSION_ID).
--    자정을 넘는 세션은 일자별로 나뉜다 — 범위 재적재(bigquery_range_purge, EVENT_DT 기준)의 전제
--    「집계가 일자 안에서 닫힌다」를 지키기 위해서다. 세션 수를 일자 간 합산하면 경계 세션이 2번 센다.
-- 🔴 속성값 = 그 일자·세션의 **첫 non-NULL 값**(EVENT_TIMESTAMP 순). ARRAY_AGG 는 NULL 을 버린다.
--    세션 안에서 값이 바뀌는 경우(로그인 전후 UP_LOGIN_STATUS 등)는 첫 값만 남는다 = 세션 진입 시점 값.
-- 🔴 원천 값은 가공하지 않는다(R2-7 · 원천 컬럼명 원칙) — '(not set)'·GTM 미치환 값(이중 중괄호로 감싼 변수명 원문) 도 원값 보존.
--    ⚠️ dbt 파일 주석에 이중 중괄호를 쓰지 말 것 — SQL 주석이어도 Jinja 가 먼저 파싱한다(O213-F 컴파일 에러 실측).
-- 제외: EP_GAD_SOURCE(라벨 없는 숫자 코드 0~5) · EP_GA_SESSION_ID 결측 이벤트(세션 귀속 불가).
-- 🔴 pre-hook 은 `macros/silver_purge.sql` RANGED_MODELS 가 분기한다(이 파일에 pre_hook 금지).
{{ config(materialized='incremental') }}

with raw as (
    select *
    from {{ source('silver_external', 'BIGQUERY_REFINED_DATA') }}
    where USER_PSEUDO_ID is not null
      and EP_GA_SESSION_ID is not null
      and {{ bigquery_range_predicate_text('EVENT_DATE') }}
)
{%- set first_cols = [
    'PLATFORM', 'DEVICE_CATEGORY', 'DEVICE_OPERATING_SYSTEM', 'DEVICE_WEB_INFO_BROWSER',
    'DEVICE_LANGUAGE', 'DEVICE_MOBILE_BRAND_NAME', 'DEVICE_WEB_INFO_HOSTNAME',
    'GEO_CONTINENT', 'GEO_SUB_CONTINENT', 'GEO_COUNTRY', 'GEO_METRO',
    'TS_SOURCE', 'TS_MEDIUM', 'CTS_MANUAL_MEDIUM', 'EP_MEDIUM',
    'STSLC_CRC_DEFAULT_CHANNEL_GROUP', 'STSLC_CRC_PRIMARY_CHANNEL_GROUP', 'STSLC_CRC_SOURCE_PLATFORM',
    'STSLC_GAC_CAMPAIGN_NAME', 'STSLC_GAC_AD_GROUP_NAME',
    'UP_MEMBER_TYPE', 'UP_DONOR_TYPE', 'UP_DONATION_TYPE', 'UP_BIZ_TYPE', 'UP_LOGIN_STATUS',
    'EP_PAYMENT_TYPE'
] %}
select
    TO_DATE(EVENT_DATE, 'YYYYMMDD')                                   as EVENT_DT,
    CAST(USER_PSEUDO_ID AS VARCHAR(200))                              as USER_PSEUDO_ID,
    try_cast(EP_GA_SESSION_ID as number)                              as BIGQUERY_SESSION_ID,
    USER_PSEUDO_ID || '-' || EP_GA_SESSION_ID                         as BIGQUERY_SESSION_KEY,
    max(try_cast(EP_GA_SESSION_NUMBER as number))                     as BIGQUERY_SESSION_NUMBER,
    min(TO_TIMESTAMP_NTZ(EVENT_TIMESTAMP / 1000000))                  as SESSION_START_TS,
{%- for c in first_cols %}
    CAST((array_agg({{ c }}) within group (order by EVENT_TIMESTAMP, BATCH_EVENT_INDEX))[0] AS VARCHAR) as {{ c }},
{%- endfor %}
    count(*)                                                          as EVENT_CNT,
    count_if(EVENT_NAME = 'page_view')                                as PAGE_VIEW_CNT,
    iff(max(iff(EP_SESSION_ENGAGED = '1', 1, 0)) = 1, true, false)    as IS_ENGAGED,
    sum(try_cast(EP_ENGAGEMENT_TIME_MSEC as number))                  as ENGAGEMENT_TIME_MSEC,
    CAST('BIGQUERY' AS VARCHAR(16777216))                             as DW_SOURCE_SYSTEM,
    CAST('SILVER.BIGQUERY_REFINED_DATA' AS VARCHAR(16777216))         as DW_SOURCE_TABLE,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                        as DW_LOAD_TS,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                        as DW_UPDATE_TS,
    NULL                                                              as DW_BATCH_ID
from raw
group by EVENT_DATE, USER_PSEUDO_ID, EP_GA_SESSION_ID
