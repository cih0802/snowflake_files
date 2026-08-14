-- GA4_DEVICE: 기기 차원 DISTINCT (platform+device.category 조합 파생: APP/M/PC), 정본 09 STEP6.
-- Co-authored with CoCo
{{ config(materialized='incremental') }}
SELECT DISTINCT
  -- GA4 공식 기준(platform 단독 불가 — PC/모바일 웹 모두 WEB): platform × device.category 조합.
  --   APP = platform IN (ANDROID, IOS) / M = WEB × (mobile|tablet) / PC = WEB × desktop
  -- 미분류(platform·category NULL, 신규 category 등)는 '(unknown)'으로 격리 — 과거 ELSE 'PC'는 PC 과대계상(2026-07-27 교정).
  CASE WHEN platform IN ('ANDROID','IOS') THEN 'APP'
       WHEN platform = 'WEB' AND device:category::STRING IN ('mobile','tablet') THEN 'M'
       WHEN platform = 'WEB' AND device:category::STRING = 'desktop' THEN 'PC'
       ELSE '(unknown)' END   AS DEVICE_TYPE,
  platform                     AS PLATFORM,
  device:category::STRING      AS DEVICE_CATEGORY,
  device:operating_system::STRING AS OS,
  device:browser::STRING       AS BROWSER,
  device:language::STRING      AS LANGUAGE,
  'GA4'                        AS DW_SOURCE_SYSTEM,
  'BRONZE_BIGQUERY.events'          AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()          AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()          AS DW_UPDATE_TS,
  NULL                         AS DW_BATCH_ID
FROM ( {{ ga4_union_shards(var('ga4_start'), var('ga4_end')) }} )
