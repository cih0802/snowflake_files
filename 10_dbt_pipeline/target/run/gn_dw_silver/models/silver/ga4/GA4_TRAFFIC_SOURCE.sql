
  
    

        create or replace transient table GN_DW.SILVER.GA4_TRAFFIC_SOURCE
         as
        (-- GA4_TRAFFIC_SOURCE: 세션 last-click 트래픽소스 DISTINCT (first-touch/collected 제외 = grain 팽창 방지), 정본 09 STEP6.
-- Co-authored with CoCo
-- FROM 절 = ga4_union_shards 매크로(전기간 샤드 UNION, 명시 30컬럼). PoC 1일→전기간 멱등 전환.

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
  FROM ( 
  
  
    
    
      
        -- ⚠️ BRONZE_GA4 컬럼도 소문자 인용식별자로 저장됨 → "col" AS COL 로 참조/승격(하류는 unquoted 대문자 참조).
        SELECT
          "event_date"                        AS event_date,
          "event_timestamp"                   AS event_timestamp,
          "event_name"                        AS event_name,
          "event_params"                      AS event_params,       -- VARIANT: LATERAL FLATTEN은 모델에서
          "user_id"                           AS user_id,            -- ⚠️VARCHAR 필수(선행0·S접두 보존)
          "user_pseudo_id"                    AS user_pseudo_id,
          "device"                            AS device,
          "geo"                               AS geo,
          "traffic_source"                    AS traffic_source,
          "collected_traffic_source"          AS collected_traffic_source,
          "session_traffic_source_last_click" AS session_traffic_source_last_click,
          "platform"                          AS platform,
          "is_active_user"                    AS is_active_user,
          "batch_ordering_id"                 AS batch_ordering_id
        FROM GN_DW.BRONZE_GA4."events_20260501"
        
      
    
  
 )
)
        );
      
  