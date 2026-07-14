-- GA4_IDENTITY: 신원 1행/pseudo (Q1 S접두 분기 + 세션 채움, 단방향=GA4_EVENT 미참조), 정본 09 STEP6.
-- Co-authored with CoCo

WITH ev AS (
    SELECT
        e.user_pseudo_id AS user_pseudo_id,
        e.user_id        AS user_id,
        MAX(IFF(p.value:key::STRING='ga_session_id', p.value:value:int_value::NUMBER, NULL)) AS ga_session_id
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
    GROUP BY e.user_pseudo_id, e.event_timestamp, e.event_name, e.batch_ordering_id, e.user_id
),
sess AS (
    SELECT user_pseudo_id || '-' || ga_session_id AS ga_session_key,
           COUNT(DISTINCT user_id) AS n_id, MAX(user_id) AS sess_uid
    FROM ev WHERE ga_session_id IS NOT NULL
    GROUP BY user_pseudo_id || '-' || ga_session_id
),
filled AS (
    SELECT
        ev.user_pseudo_id,
        CASE WHEN ev.user_id IS NOT NULL              THEN ev.user_id
             WHEN ev.ga_session_id IS NOT NULL AND s.n_id = 1 THEN s.sess_uid
             ELSE NULL END AS member_id,
        CASE WHEN ev.user_id IS NOT NULL              THEN 'DIRECT'
             WHEN ev.ga_session_id IS NOT NULL AND s.n_id = 1 THEN 'SESSION_FILL'
             ELSE NULL END AS id_resolution
    FROM ev
    LEFT JOIN sess s
        ON ev.ga_session_id IS NOT NULL
       AND s.ga_session_key = ev.user_pseudo_id || '-' || ev.ga_session_id
)
SELECT
    user_pseudo_id                                                          AS USER_PSEUDO_ID,
    MAX(member_id)                                                          AS GA_MEMBER_ID,
    CASE WHEN MAX(member_id) ILIKE 'S%' THEN 'ONCE' ELSE 'FDRM' END          AS MEMBER_TYPE,
    IFF(MAX(member_id) ILIKE 'S%', NULL, MAX(member_id))                     AS MBER_NO,
    IFF(MAX(member_id) ILIKE 'S%', MAX(member_id), NULL)                     AS ONCE_MBER_NO,
    IFF(MIN(IFF(id_resolution='DIRECT',0,1)) = 0, 'DIRECT', 'SESSION_FILL')  AS ID_RESOLUTION,
    'GA4'               AS DW_SOURCE_SYSTEM,
    'BRONZE_GA4.events' AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP() AS DW_LOAD_TS,
    CURRENT_TIMESTAMP() AS DW_UPDATE_TS,
    NULL                AS DW_BATCH_ID
FROM filled
WHERE member_id IS NOT NULL
GROUP BY user_pseudo_id