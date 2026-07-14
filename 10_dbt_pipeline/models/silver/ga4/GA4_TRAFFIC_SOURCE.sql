-- GA4_TRAFFIC_SOURCE: 세션 last-click 트래픽소스 DISTINCT (first-touch/collected 제외 = grain 팽창 방지), 정본 09 STEP6.
-- Co-authored with CoCo
-- FROM 절 = ga4_union_shards 매크로(전기간 샤드 UNION, 명시 30컬럼). PoC 1일→전기간 멱등 전환.
{{ config(materialized='incremental') }}
SELECT DISTINCT
  NULLIF(NULLIF(s:manual_campaign:source::STRING,'(not set)'),'(direct)')                       AS UTM_SOURCE,
  NULLIF(NULLIF(NULLIF(s:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)')       AS UTM_MEDIUM,
  NULLIF(s:manual_campaign:campaign_name::STRING,'(not set)')                                    AS UTM_CAMPAIGN,
  NULLIF(s:manual_campaign:content::STRING,'(not set)')                                          AS UTM_CONTENT,
  NULLIF(s:manual_campaign:term::STRING,'(not set)')                                             AS UTM_TERM,
  CONCAT_WS(' / ',
    NULLIF(NULLIF(s:manual_campaign:source::STRING,'(not set)'),'(direct)'),
    NULLIF(NULLIF(NULLIF(s:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)'))    AS SOURCE_MEDIUM,
  s:cross_channel_campaign:source::STRING                                                        AS XCHAN_SOURCE,
  s:cross_channel_campaign:medium::STRING                                                        AS XCHAN_MEDIUM,
  s:cross_channel_campaign:campaign_name::STRING                                                 AS XCHAN_CAMPAIGN,
  s:cross_channel_campaign:default_channel_group::STRING                                         AS DEFAULT_CHANNEL_GROUP,
  'GA4'               AS DW_SOURCE_SYSTEM,
  'BRONZE_GA4.events' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP() AS DW_LOAD_TS,
  CURRENT_TIMESTAMP() AS DW_UPDATE_TS,
  NULL                AS DW_BATCH_ID
FROM (
  SELECT session_traffic_source_last_click AS s
  FROM ( {{ ga4_union_shards(var('ga4_start'), var('ga4_end')) }} )
)
