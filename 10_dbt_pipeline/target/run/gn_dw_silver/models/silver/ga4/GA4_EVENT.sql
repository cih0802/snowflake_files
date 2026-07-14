
  
    

        create or replace transient table GN_DW.SILVER.GA4_EVENT
         as
        (-- GA4_EVENT: 이벤트 팩트 소스 (FLATTEN + param 승격 + 07 §5-A 세션 채움 2단계 CTE), 정본 09 STEP6.
-- Co-authored with CoCo
-- 단방향: BRONZE_GA4(매크로)만 참조. n_id>=2=CONFLICT(미채움). PK GROUP BY dedup.

WITH ev AS (
    SELECT
        e.user_pseudo_id                                                     AS user_pseudo_id,
        e.event_timestamp                                                    AS event_timestamp,
        e.event_name                                                         AS event_name,
        e.batch_ordering_id                                                  AS batch_ordering_id,
        e.event_date                                                         AS event_date,
        e.user_id                                                            AS user_id,
        e.device                                                             AS device,
        e.geo                                                                AS geo,
        e.platform                                                           AS platform,
        e.is_active_user                                                     AS is_active_user,
        e.session_traffic_source_last_click                                  AS stlc,
        MAX(IFF(p.value:key::STRING='ga_session_id',     p.value:value:int_value::NUMBER, NULL)) AS ga_session_id,
        MAX(IFF(p.value:key::STRING='ga_session_number', p.value:value:int_value::NUMBER, NULL)) AS ga_session_number,
        MAX(IFF(p.value:key::STRING='session_engaged',
            COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL)) AS session_engaged,
        MAX(IFF(p.value:key::STRING='engagement_time_msec', p.value:value:int_value::NUMBER, NULL)) AS engagement_time_msec,
        MAX(IFF(p.value:key::STRING='page_location', p.value:value:string_value::STRING, NULL))     AS page_location,
        MAX(IFF(p.value:key::STRING='page_title',    p.value:value:string_value::STRING, NULL))     AS page_title,
        MAX(IFF(p.value:key::STRING='page_referrer', p.value:value:string_value::STRING, NULL))     AS page_referrer,
        MAX(IFF(p.value:key::STRING='event_category', p.value:value:string_value::STRING, NULL))    AS event_category,
        MAX(IFF(p.value:key::STRING='event_action',   p.value:value:string_value::STRING, NULL))    AS event_action,
        MAX(IFF(p.value:key::STRING='event_label',
            COALESCE(p.value:value:string_value::STRING, p.value:value:int_value::STRING), NULL))   AS event_label,
        MAX(IFF(p.value:key::STRING='percent_scrolled', p.value:value:int_value::NUMBER, NULL))     AS percent_scrolled,
        MAX(IFF(p.value:key::STRING='link_url',  p.value:value:string_value::STRING, NULL))         AS link_url,
        MAX(IFF(p.value:key::STRING='link_text', p.value:value:string_value::STRING, NULL))         AS link_text
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
    GROUP BY
        e.user_pseudo_id, e.event_timestamp, e.event_name, e.batch_ordering_id, e.event_date,
        e.user_id, e.device, e.geo, e.platform, e.is_active_user, e.session_traffic_source_last_click
),
sess AS (
    SELECT
        user_pseudo_id || '-' || ga_session_id AS ga_session_key,
        COUNT(DISTINCT user_id)                 AS n_id,
        MAX(user_id)                            AS sess_uid
    FROM ev
    WHERE ga_session_id IS NOT NULL
    GROUP BY user_pseudo_id || '-' || ga_session_id
)
SELECT
    ev.user_pseudo_id                                            AS USER_PSEUDO_ID,
    ev.event_timestamp                                           AS EVENT_TIMESTAMP,
    ev.event_name                                                AS EVENT_NAME,
    ev.batch_ordering_id                                         AS BATCH_ORDERING_ID,
    ev.event_date                                                AS EVENT_DATE,
    TO_DATE(ev.event_date,'YYYYMMDD')                            AS EVENT_DT,
    TO_TIMESTAMP(ev.event_timestamp/1000000)                     AS EVENT_TS,
    ev.user_id                                                   AS USER_ID,
    ev.ga_session_id                                             AS GA_SESSION_ID,
    ev.ga_session_number                                         AS GA_SESSION_NUMBER,
    IFF(ev.ga_session_id IS NULL, NULL, ev.user_pseudo_id || '-' || ev.ga_session_id) AS GA_SESSION_KEY,
    CASE WHEN ev.user_id IS NOT NULL   THEN ev.user_id
         WHEN ev.ga_session_id IS NULL THEN NULL
         WHEN s.n_id = 1               THEN s.sess_uid
         ELSE NULL END                                           AS USER_ID_FILLED,
    CASE WHEN ev.user_id IS NOT NULL   THEN 'DIRECT'
         WHEN ev.ga_session_id IS NULL THEN 'UNRESOLVED'
         WHEN s.n_id = 1               THEN 'SESSION_FILL'
         WHEN s.n_id >= 2              THEN 'CONFLICT'
         ELSE 'UNRESOLVED' END                                   AS ID_RESOLUTION,
    ev.session_engaged                                           AS SESSION_ENGAGED,
    ev.engagement_time_msec                                      AS ENGAGEMENT_TIME_MSEC,
    ev.page_location                                             AS PAGE_LOCATION,
    ev.page_title                                                AS PAGE_TITLE,
    ev.page_referrer                                             AS PAGE_REFERRER,
    ev.event_category                                            AS EVENT_CATEGORY,
    ev.event_action                                              AS EVENT_ACTION,
    ev.event_label                                               AS EVENT_LABEL,
    ev.percent_scrolled                                          AS PERCENT_SCROLLED,
    ev.link_url                                                  AS LINK_URL,
    ev.link_text                                                 AS LINK_TEXT,
    CASE WHEN ev.platform IN ('ANDROID','IOS') THEN 'APP'
         WHEN ev.device:category::STRING IN ('mobile','tablet') THEN 'M' ELSE 'PC' END AS DEVICE_TYPE,
    ev.device:category::STRING                                   AS DEVICE_CATEGORY,
    ev.device:operating_system::STRING                           AS OS,
    ev.geo:country::STRING                                       AS GEO_COUNTRY,
    ev.geo:city::STRING                                          AS GEO_CITY,
    NULLIF(NULLIF(ev.stlc:manual_campaign:source::STRING,'(not set)'),'(direct)')                 AS UTM_SOURCE,
    NULLIF(NULLIF(NULLIF(ev.stlc:manual_campaign:medium::STRING,'(not set)'),'(none)'),'(direct)') AS UTM_MEDIUM,
    NULLIF(ev.stlc:manual_campaign:campaign_name::STRING,'(not set)')                             AS UTM_CAMPAIGN,
    ev.stlc:cross_channel_campaign:default_channel_group::STRING AS DEFAULT_CHANNEL_GROUP,
    ev.platform                                                  AS PLATFORM,
    ev.is_active_user                                            AS IS_ACTIVE_USER,
    'GA4'               AS DW_SOURCE_SYSTEM,
    'BRONZE_GA4.events' AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP() AS DW_LOAD_TS,
    CURRENT_TIMESTAMP() AS DW_UPDATE_TS,
    NULL                AS DW_BATCH_ID
FROM ev
LEFT JOIN sess s
    ON ev.ga_session_id IS NOT NULL
   AND s.ga_session_key = ev.user_pseudo_id || '-' || ev.ga_session_id
        );
      
  