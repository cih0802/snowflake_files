-- GA4_TRAFFIC_SOURCE: 트래픽소스 차원 (session last-click DISTINCT, 센티넬 NULLIF)
-- Co-authored with CoCo
{{ config(materialized='table') }}

with src as (
    {{ ga4_union_shards('20000101', '99991231') }}
)

select distinct
    NULLIF(NULLIF(session_traffic_source_last_click:manual_campaign:source::STRING,'(not set)'),'(direct)')                       as UTM_SOURCE,
    NULLIF(NULLIF(NULLIF(session_traffic_source_last_click:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)')      as UTM_MEDIUM,
    NULLIF(session_traffic_source_last_click:manual_campaign:campaign_name::STRING,'(not set)')                                   as UTM_CAMPAIGN,
    NULLIF(session_traffic_source_last_click:manual_campaign:content::STRING,'(not set)')                                         as UTM_CONTENT,
    NULLIF(session_traffic_source_last_click:manual_campaign:term::STRING,'(not set)')                                           as UTM_TERM,
    CONCAT_WS(' / ',
        NULLIF(NULLIF(session_traffic_source_last_click:manual_campaign:source::STRING,'(not set)'),'(direct)'),
        NULLIF(NULLIF(NULLIF(session_traffic_source_last_click:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)')) as SOURCE_MEDIUM,
    session_traffic_source_last_click:cross_channel_campaign:source::STRING                                                       as XCHAN_SOURCE,
    session_traffic_source_last_click:cross_channel_campaign:medium::STRING                                                       as XCHAN_MEDIUM,
    session_traffic_source_last_click:cross_channel_campaign:campaign_name::STRING                                                as XCHAN_CAMPAIGN,
    session_traffic_source_last_click:cross_channel_campaign:default_channel_group::STRING                                        as DEFAULT_CHANNEL_GROUP,
    NULLIF(traffic_source:source::STRING,'(not set)')                                                                            as TS_SOURCE,
    NULLIF(traffic_source:medium::STRING,'(not set)')                                                                            as TS_MEDIUM,
    NULLIF(traffic_source:name::STRING,'(not set)')                                                                              as TS_CAMPAIGN,
    collected_traffic_source:manual_source::STRING                                                                               as CTS_SOURCE,
    collected_traffic_source:manual_medium::STRING                                                                              as CTS_MEDIUM,
    'GA4'                              as DW_SOURCE_SYSTEM,
    'BRONZE_GA4.EVENTS_*'              as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from src
