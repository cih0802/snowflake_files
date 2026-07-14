-- GA4_DEVICE: 기기 차원 DISTINCT (platform/device 파생: APP/M/PC), 정본 09 STEP6.
-- Co-authored with CoCo

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