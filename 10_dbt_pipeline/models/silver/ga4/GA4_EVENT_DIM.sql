-- GA4_EVENT_DIM: 이벤트 정의 DISTINCT (event_params 승격: category/label/action), 정본 09 STEP6.
-- Co-authored with CoCo
{{ config(materialized='incremental') }}
SELECT DISTINCT
  EVENT_NAME          AS EVENT_NAME,
  EVENT_CATEGORY      AS EVENT_CATEGORY,
  EVENT_LABEL         AS EVENT_LABEL,
  EVENT_ACTION        AS EVENT_ACTION,
  'GA4'               AS DW_SOURCE_SYSTEM,
  'BRONZE_GA4.events' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP() AS DW_LOAD_TS,
  CURRENT_TIMESTAMP() AS DW_UPDATE_TS,
  NULL                AS DW_BATCH_ID
FROM (
  SELECT e.event_name AS EVENT_NAME,
    MAX(IFF(p.value:key::STRING='event_category', p.value:value:string_value::STRING, NULL)) AS EVENT_CATEGORY,
    MAX(IFF(p.value:key::STRING='event_label',
        COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL)) AS EVENT_LABEL,
    MAX(IFF(p.value:key::STRING='event_action', p.value:value:string_value::STRING, NULL)) AS EVENT_ACTION
  FROM ( {{ ga4_union_shards(var('ga4_start'), var('ga4_end')) }} ) e, LATERAL FLATTEN(input => e.event_params) p
  GROUP BY e.event_name, e.event_timestamp, e.user_pseudo_id, e.batch_ordering_id
)
