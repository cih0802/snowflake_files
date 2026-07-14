-- GA4_EVENT_DIM: 이벤트 정의 DISTINCT (event_params 승격: category/label/action), 정본 09 STEP6.
-- Co-authored with CoCo

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
        
      
    
  
 ) e, LATERAL FLATTEN(input => e.event_params) p
  GROUP BY e.event_name, e.event_timestamp, e.user_pseudo_id, e.batch_ordering_id
)