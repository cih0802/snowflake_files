-- GA4_EVENT: 이벤트 팩트 소스 (전체 FLATTEN + param 승격, 72h 소급보정 merge)
-- Co-authored with CoCo
-- ⚠️ 증분: GA4는 D+3까지 소급수정 → is_incremental 시 D-3~D-1 재처리, merge로 기존 보정
-- ⚠️ 최초 전체적재: dbt run --select silver.ga4 --full-refresh (else 분기 = 전체 shard UNION)
{{ config(
    materialized='incremental',
    unique_key=['USER_PSEUDO_ID','EVENT_TIMESTAMP','EVENT_NAME','BATCH_ORDERING_ID'],
    incremental_strategy='merge'
) }}

with src as (
    {% if is_incremental() %}
        {{ ga4_union_shards(
            (modules.datetime.date.today() - modules.datetime.timedelta(days=3)).strftime('%Y%m%d'),
            (modules.datetime.date.today() - modules.datetime.timedelta(days=1)).strftime('%Y%m%d')
        ) }}
    {% else %}
        {{ ga4_union_shards('20000101', '99991231') }}
    {% endif %}
)

select
    e.user_pseudo_id                                                                                     as USER_PSEUDO_ID,
    e.event_timestamp                                                                                    as EVENT_TIMESTAMP,
    e.event_name                                                                                         as EVENT_NAME,
    e.batch_ordering_id                                                                                  as BATCH_ORDERING_ID,
    e.event_date                                                                                         as EVENT_DATE,
    TO_DATE(e.event_date,'YYYYMMDD')                                                                     as EVENT_DT,
    TO_TIMESTAMP(e.event_timestamp/1000000)::TIMESTAMP_NTZ                                               as EVENT_TS,
    e.user_id                                                                                            as USER_ID,   -- ⚠️VARCHAR 유지
    MAX(IFF(p.value:key::STRING='ga_session_id', p.value:value:int_value::NUMBER, NULL))                 as GA_SESSION_ID,
    MAX(IFF(p.value:key::STRING='ga_session_number', p.value:value:int_value::NUMBER, NULL))             as GA_SESSION_NUMBER,
    MAX(IFF(p.value:key::STRING='session_engaged',
        COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL))            as SESSION_ENGAGED,
    MAX(IFF(p.value:key::STRING='engagement_time_msec', p.value:value:int_value::NUMBER, NULL))          as ENGAGEMENT_TIME_MSEC,
    MAX(IFF(p.value:key::STRING='page_location', p.value:value:string_value::STRING, NULL))              as PAGE_LOCATION,
    MAX(IFF(p.value:key::STRING='page_title', p.value:value:string_value::STRING, NULL))                 as PAGE_TITLE,
    MAX(IFF(p.value:key::STRING='page_referrer', p.value:value:string_value::STRING, NULL))              as PAGE_REFERRER,
    MAX(IFF(p.value:key::STRING='event_category', p.value:value:string_value::STRING, NULL))             as EVENT_CATEGORY,
    MAX(IFF(p.value:key::STRING='event_action', p.value:value:string_value::STRING, NULL))               as EVENT_ACTION,
    MAX(IFF(p.value:key::STRING='event_label',
        COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL))            as EVENT_LABEL,
    MAX(IFF(p.value:key::STRING='percent_scrolled', p.value:value:int_value::NUMBER, NULL))              as PERCENT_SCROLLED,
    MAX(IFF(p.value:key::STRING='link_url', p.value:value:string_value::STRING, NULL))                   as LINK_URL,
    MAX(IFF(p.value:key::STRING='link_text', p.value:value:string_value::STRING, NULL))                  as LINK_TEXT,
    CASE WHEN e.platform IN ('ANDROID','IOS') THEN 'APP'
         WHEN e.device:category::STRING IN ('mobile','tablet') THEN 'M' ELSE 'PC' END                    as DEVICE_TYPE,
    e.device:category::STRING                                                                            as DEVICE_CATEGORY,
    e.device:operating_system::STRING                                                                    as OS,
    e.geo:country::STRING                                                                                as GEO_COUNTRY,
    e.geo:city::STRING                                                                                   as GEO_CITY,
    NULLIF(NULLIF(e.session_traffic_source_last_click:manual_campaign:source::STRING,'(not set)'),'(direct)')                    as UTM_SOURCE,
    NULLIF(NULLIF(NULLIF(e.session_traffic_source_last_click:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)')   as UTM_MEDIUM,
    NULLIF(e.session_traffic_source_last_click:manual_campaign:campaign_name::STRING,'(not set)')                                as UTM_CAMPAIGN,
    e.session_traffic_source_last_click:cross_channel_campaign:default_channel_group::STRING             as DEFAULT_CHANNEL_GROUP,
    e.platform                                                                                           as PLATFORM,
    e.is_active_user                                                                                     as IS_ACTIVE_USER,
    'GA4'                              as DW_SOURCE_SYSTEM,
    'BRONZE_GA4.EVENTS_*'              as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from src e, LATERAL FLATTEN(input => e.event_params) p
group by
    e.user_pseudo_id, e.event_timestamp, e.event_name, e.batch_ordering_id, e.event_date,
    e.user_id, e.is_active_user, e.platform, e.device, e.geo, e.session_traffic_source_last_click
