-- GA4_DEVICE: 디바이스 차원 (device+platform → PC/M/APP 파생 DISTINCT)
-- Co-authored with CoCo
{{ config(materialized='table') }}

with src as (
    {{ ga4_union_shards('20000101', '99991231') }}
)

select distinct
    CASE WHEN platform IN ('ANDROID','IOS') THEN 'APP'
         WHEN device:category::STRING IN ('mobile','tablet') THEN 'M'
         ELSE 'PC' END                 as DEVICE_TYPE,
    platform                           as PLATFORM,
    device:category::STRING            as DEVICE_CATEGORY,
    device:operating_system::STRING    as OS,
    device:browser::STRING             as BROWSER,
    device:language::STRING            as LANGUAGE,
    'GA4'                              as DW_SOURCE_SYSTEM,
    'BRONZE_GA4.EVENTS_*'              as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                  as DW_UPDATE_TS,
    '{{ invocation_id }}'                                as DW_BATCH_ID
from src
