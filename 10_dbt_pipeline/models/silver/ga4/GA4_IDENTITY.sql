-- GA4_IDENTITY: 신원 1행/pseudo (Q1 S접두 분기 + 세션 채움, 단방향=GA4_EVENT 미참조), 정본 09 STEP6.
-- Co-authored with CoCo
{{ config(materialized='incremental') }}
WITH ev AS (
    SELECT
        e.user_pseudo_id AS user_pseudo_id,
        e.user_id        AS user_id,
        MAX(IFF(p.value:key::STRING='ga_session_id', p.value:value:int_value::NUMBER, NULL)) AS ga_session_id
    FROM ( {{ ga4_union_shards(var('ga4_start'), var('ga4_end')) }} ) e, LATERAL FLATTEN(input => e.event_params) p
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
