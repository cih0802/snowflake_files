-- GA4_DEVICE: 기기 차원 DISTINCT (platform/device 파생: APP/M/PC), 정본 09 STEP6.
-- Co-authored with CoCo
{{ config(materialized='table') }}
SELECT DISTINCT
  CASE WHEN platform IN ('ANDROID','IOS') THEN 'APP'
       WHEN device:category::STRING IN ('mobile','tablet') THEN 'M'
       ELSE 'PC' END          AS DEVICE_TYPE,
  platform                     AS PLATFORM,
  device:category::STRING      AS DEVICE_CATEGORY,
  device:operating_system::STRING AS OS,
  device:browser::STRING       AS BROWSER,
  device:language::STRING      AS LANGUAGE,
  'GA4'                        AS DW_SOURCE_SYSTEM,
  'BRONZE_GA4.events'          AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()          AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()          AS DW_UPDATE_TS,
  NULL                         AS DW_BATCH_ID
FROM ( {{ ga4_union_shards(var('ga4_start'), var('ga4_end')) }} )
