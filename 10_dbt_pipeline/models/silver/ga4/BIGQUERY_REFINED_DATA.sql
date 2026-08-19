-- BIGQUERY_REFINED_DATA: BRONZE_BIGQUERY.EVENTS 평탄화 통합 기반 테이블 (SILVER GA4 계열의 유일 입력).
-- Co-authored with CoCo
--
-- 이 모델이 존재하는 이유 (2026-08-19 O87 · 사용자 요건 + 설계문서 07 §「🟠 예정」)
--   종전에는 GA4_* 5모델이 **각자** BRONZE 를 읽고 그중 3개가 LATERAL FLATTEN 을 했다
--   ⇒ 2.86억행 × VARIANT 11개를 5회 스캔. 이 모델이 평탄화·param 승격·VARIANT 경로 추출을
--   **1회로 통합**하고, 하류 5종은 스칼라 컬럼만 읽는다.
--   설계문서 07 머리말 §「🟠 예정 — SILVER 평탄화 통합 테이블」이 전제 3개를 이미 못박았고
--   이 모델은 그 전제를 그대로 구현한다:
--     ① 소스는 EVENTS 단일  ② EVENT_DT 파티션 키 유지  ③ SRC_TABLE·SRC_FILE_NAME 계보 승계
--
-- ⚠️ 계층 규칙 — 이 테이블은 SILVER 안에서 하류가 참조하는 **기반 테이블**이다(계층 내 파생).
--    허용 근거 = DEC-37(30_설계_의사결정). 선례 = AGENCY_AD_ROW_DGT/_REBRDC/_VIDEO → 성과·방송·사례·디지털 4테이블.
--    금지선은 그대로다: **집계 롤업(월·코호트)과 중복 소유권은 여기서도 금지**. 이 모델은
--    grain 을 바꾸지 않고(이벤트 1행) DISTINCT 축소도 하지 않는다.
--
-- ⚠️ 명명 — SILVER 는 도메인 접두(GA4_*)가 규약이고 이 테이블만 **원천 접두(BIGQUERY_)** 다.
--    근거 = DEC-38. 기반 테이블은 「BigQuery export 를 평탄화한 것」이라는 원천 사실을 이름에 담고,
--    도메인 해석이 들어간 산출물은 GA4_* 로 남긴다.
--
-- 🔴 비용 — EVENT_DT 범위 제한이 이 모델의 유일한 방어선이다(설계문서 07: 빼면 2.86억행 전량 스캔).
--    범위는 var(ga4_dt_start, ga4_dt_end) 로 준다.
-- 🔴 pre-hook 은 여기서 선언하지 않는다 — `macros/silver_purge.sql` 이 이 모델을 range 모델로
--    인식해 **TRUNCATE 대신 범위 DELETE** 를 낸다(dbt hook 누적 사고 방지 · dbt_project.yml 참조).
--    ⚠️ 모델명을 바꾸면 `silver_purge.RANGED_MODELS` 도 함께 고쳐야 한다. 빠뜨리면 조용히
--       TRUNCATE 경로로 돌아가 월 단위 분할 적재에서 앞 달이 지워진다.
--
-- grain = 1행 / (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, EVENT_SEQ)
--   GROUP BY 는 event_params 를 pivot 하기 위한 것이고, 부수적으로 11개 스칼라/VARIANT 가
--   전부 동일한 행을 접는다(종전 GA4_EVENT 와 동일 동작 · 2025-06 실측 9.6%).
--   EVENT_SEQ = GA4-PK-1 조치① surrogate tiebreaker → 아래 참조.
{{ config(materialized='incremental') }}

WITH src AS (
    -- ⚠️ 명시 컬럼 선택(SELECT * 금지 · 설계문서 07 §1 방식 B).
    --    BRONZE 데이터 31컬럼은 소문자 인용식별자이고 계보 4컬럼은 대문자 무따옴표다.
    --    매핑 제외 4컬럼(전 기간 전건 NULL · 설계문서 07 §7-A):
    --      app_info · event_dimensions · publisher · event_original_occurrence_timestamp
    SELECT
        "event_date"                        AS event_date,
        "event_timestamp"                   AS event_timestamp,
        "event_name"                        AS event_name,
        "event_params"                      AS event_params,
        "user_id"                           AS user_id,
        "user_pseudo_id"                    AS user_pseudo_id,
        "device"                            AS device,
        "geo"                               AS geo,
        "platform"                          AS platform,
        "is_active_user"                    AS is_active_user,
        "batch_ordering_id"                 AS batch_ordering_id,
        "session_traffic_source_last_click" AS stlc,
        SRC_TABLE                           AS src_table,
        EVENT_DT                            AS event_dt,
        SRC_FILE_NAME                       AS src_file_name,
        LOAD_TS                             AS bronze_load_ts
    FROM {{ source('bronze_bigquery', 'EVENTS') }}
    WHERE EVENT_DT >= TO_DATE('{{ var("ga4_dt_start") }}')
      AND EVENT_DT <= TO_DATE('{{ var("ga4_dt_end") }}')
),

-- event_params(VARIANT ARRAY) → 스칼라 승격. 혼합타입은 COALESCE(string, int) (설계문서 07 §7-B).
flat AS (
    SELECT
        e.user_pseudo_id,
        e.event_timestamp,
        e.event_name,
        e.event_date,
        e.event_dt,
        e.user_id,
        e.device,
        e.geo,
        e.platform,
        e.is_active_user,
        e.batch_ordering_id,
        e.stlc,
        e.src_table,
        e.src_file_name,
        e.bronze_load_ts,
        MAX(IFF(p.value:key::STRING = 'ga_session_id',
            p.value:value:int_value::NUMBER, NULL))                        AS ga_session_id,
        MAX(IFF(p.value:key::STRING = 'ga_session_number',
            p.value:value:int_value::NUMBER, NULL))                        AS ga_session_number,
        MAX(IFF(p.value:key::STRING = 'session_engaged',
            COALESCE(p.value:value:string_value::STRING,
                     p.value:value:int_value::STRING), NULL))              AS session_engaged,
        MAX(IFF(p.value:key::STRING = 'engagement_time_msec',
            p.value:value:int_value::NUMBER, NULL))                        AS engagement_time_msec,
        MAX(IFF(p.value:key::STRING = 'page_location',
            p.value:value:string_value::STRING, NULL))                     AS page_location,
        MAX(IFF(p.value:key::STRING = 'page_title',
            p.value:value:string_value::STRING, NULL))                     AS page_title,
        MAX(IFF(p.value:key::STRING = 'page_referrer',
            p.value:value:string_value::STRING, NULL))                     AS page_referrer,
        MAX(IFF(p.value:key::STRING = 'event_category',
            p.value:value:string_value::STRING, NULL))                     AS event_category,
        MAX(IFF(p.value:key::STRING = 'event_action',
            p.value:value:string_value::STRING, NULL))                     AS event_action,
        MAX(IFF(p.value:key::STRING = 'event_label',
            COALESCE(p.value:value:string_value::STRING,
                     p.value:value:int_value::STRING), NULL))              AS event_label,
        MAX(IFF(p.value:key::STRING = 'percent_scrolled',
            p.value:value:int_value::NUMBER, NULL))                        AS percent_scrolled,
        MAX(IFF(p.value:key::STRING = 'link_url',
            p.value:value:string_value::STRING, NULL))                     AS link_url,
        MAX(IFF(p.value:key::STRING = 'link_text',
            p.value:value:string_value::STRING, NULL))                     AS link_text
    FROM src e, LATERAL FLATTEN(input => e.event_params) p
    GROUP BY
        e.user_pseudo_id, e.event_timestamp, e.event_name, e.event_date, e.event_dt,
        e.user_id, e.device, e.geo, e.platform, e.is_active_user, e.batch_ordering_id,
        e.stlc, e.src_table, e.src_file_name, e.bronze_load_ts
)

SELECT
    -- ── PK 4키 ────────────────────────────────────────────────────────────────
    f.user_pseudo_id                                             AS USER_PSEUDO_ID,
    f.event_timestamp                                            AS EVENT_TIMESTAMP,
    f.event_name                                                 AS EVENT_NAME,
    -- 🟢 GA4-PK-1 조치① — surrogate tiebreaker (손실 0 · 사용자 결정 2026-08-19).
    --    종전 4번째 PK 키 BATCH_ORDERING_ID 는 원천 events_20240719 부터 생긴 컬럼이라
    --    2024-01-01~07-18 · 199일 · 48,862,926행(17.10%)이 NOT NULL 위반으로 적재 불가였다.
    --    3키로 낮춰도 2024-06 기준 3.679%(238,454행) 중복이 남아 단순 제거도 불가였다.
    --    ⇒ 계보(SRC_FILE_NAME) + BATCH_ORDERING_ID 순으로 결정적 정렬해 순번을 부여한다.
    --    ⚠️ 결정성의 한계: 아래 ORDER BY 전 컬럼이 동일한 두 행은 순번이 뒤바뀔 수 있다.
    --       단 그런 행은 위 GROUP BY 에서 이미 접혔으므로(11컬럼 + 계보 3컬럼 전부 동일)
    --       잔존 가능성은 이론적이다. 재실행 간 안정성은 적재 후 DQ 로 확인할 것(미결 GA4-SEQ-1).
    ROW_NUMBER() OVER (
        PARTITION BY f.user_pseudo_id, f.event_timestamp, f.event_name
        ORDER BY f.batch_ordering_id NULLS LAST,
                 f.src_file_name,
                 f.event_date,
                 f.user_id NULLS LAST,
                 f.platform NULLS LAST,
                 f.device:category::STRING NULLS LAST,
                 f.device:operating_system::STRING NULLS LAST,
                 f.geo:country::STRING NULLS LAST,
                 f.geo:city::STRING NULLS LAST,
                 f.ga_session_id NULLS LAST
    )                                                            AS EVENT_SEQ,

    -- ── 시간축 ────────────────────────────────────────────────────────────────
    f.event_date                                                 AS EVENT_DATE,
    f.event_dt                                                   AS EVENT_DT,
    TO_TIMESTAMP(f.event_timestamp / 1000000)                    AS EVENT_TS,

    -- ── 신원 ──────────────────────────────────────────────────────────────────
    -- 🟢 GA4-LEN-1 조치① — VARCHAR(10) → VARCHAR(64). 원본 불변 보존(설계문서 07 §5-A).
    f.user_id                                                    AS USER_ID,
    -- 🟢 GA4-LEN-1 조치② — ID 체계 분류축. 조치①만 하면 IDENTITY_MEMBER_XREF 매칭 분모에
    --    비회원 ID 가 섞여 채움률이 조용히 왜곡된다(설계문서 07 §7-B).
    --    실측 6종(전 기간): 7자리 CRM 399,773id · S+8자리 16,907id · app-+32hex 233id
    --                      · app-+uuid 8id · 이메일 1id · 문자열 'null' 1id.
    --    ⚠️ 라벨 창작 금지(DEC-17-B · R2-7) — 원천 문자열은 USER_ID 에 그대로 보존하고
    --       여기서는 분류만 부여한다. 신규 포맷은 'UNCLASSIFIED' 로 격리해 조용히 섞이지 않게 한다.
    CASE WHEN f.user_id IS NULL                       THEN NULL
         WHEN f.user_id RLIKE '^[0-9]{7}$'            THEN 'MBER_NO'
         WHEN f.user_id RLIKE '^S[0-9]{8}$'           THEN 'ONCE_MBER_NO'
         WHEN STARTSWITH(f.user_id, 'app-')           THEN 'APP'
         WHEN POSITION('@', f.user_id) > 0            THEN 'EMAIL'
         WHEN LOWER(f.user_id) = 'null'               THEN 'INVALID'
         ELSE 'UNCLASSIFIED' END                                 AS ID_SCHEME,

    -- ── 세션 (event_params 승격) ───────────────────────────────────────────────
    f.ga_session_id                                              AS GA_SESSION_ID,
    f.ga_session_number                                          AS GA_SESSION_NUMBER,
    -- 세션 자연키는 반드시 복합((user_pseudo_id, ga_session_id)) — ga_session_id 는
    -- user_pseudo_id 내에서만 유일하다(설계문서 07 §5-A). 단독 사용 = 다른 사용자 세션 오병합.
    IFF(f.ga_session_id IS NULL, NULL,
        f.user_pseudo_id || '-' || f.ga_session_id)               AS GA_SESSION_KEY,
    f.session_engaged                                            AS SESSION_ENGAGED,
    f.engagement_time_msec                                       AS ENGAGEMENT_TIME_MSEC,

    -- ── 페이지·이벤트 속성 (event_params 승격) ─────────────────────────────────
    f.page_location                                              AS PAGE_LOCATION,
    f.page_title                                                 AS PAGE_TITLE,
    f.page_referrer                                              AS PAGE_REFERRER,
    f.event_category                                             AS EVENT_CATEGORY,
    f.event_action                                               AS EVENT_ACTION,
    f.event_label                                                AS EVENT_LABEL,
    f.percent_scrolled                                           AS PERCENT_SCROLLED,
    f.link_url                                                   AS LINK_URL,
    f.link_text                                                  AS LINK_TEXT,

    -- ── 기기 (device VARIANT 승격) ─────────────────────────────────────────────
    -- GA4 공식 기준: platform × device.category 조합(platform 단독 불가 — PC/모바일 웹 모두 WEB).
    --   APP = platform IN (ANDROID, IOS) / M = WEB × (mobile|tablet) / PC = WEB × desktop
    -- 미분류는 '(unknown)' 격리(2026-07-27 교정 · 과거 ELSE 'PC' 는 PC 과대계상).
    -- ⚠️ 이 CASE 는 종전에 GA4_EVENT·GA4_DEVICE 두 곳에 중복 존재했다 — 여기서 1회로 통합한다.
    -- ⚠️ 전 기간 실측 device:category 4종 — mobile 202,329,180 · desktop 79,892,714
    --    · tablet 3,454,195 · **smart tv 499**. `smart tv` 는 현재 '(unknown)' 으로 격리된다.
    --    DEVICE_TYPE 에 'TV' 를 신설할지는 GOLD DIM_DEVICE 계약 변경이라 미결로 둔다(GA4-TV-1).
    CASE WHEN f.platform IN ('ANDROID','IOS')                                       THEN 'APP'
         WHEN f.platform = 'WEB' AND f.device:category::STRING IN ('mobile','tablet') THEN 'M'
         WHEN f.platform = 'WEB' AND f.device:category::STRING = 'desktop'            THEN 'PC'
         ELSE '(unknown)' END                                    AS DEVICE_TYPE,
    f.device:category::STRING                                    AS DEVICE_CATEGORY,
    f.device:operating_system::STRING                            AS OS,
    f.device:browser::STRING                                     AS BROWSER,
    f.device:language::STRING                                    AS LANGUAGE,
    f.platform                                                   AS PLATFORM,
    f.is_active_user                                             AS IS_ACTIVE_USER,

    -- ── 지역 (geo VARIANT 승격) ────────────────────────────────────────────────
    f.geo:country::STRING                                        AS GEO_COUNTRY,
    f.geo:city::STRING                                           AS GEO_CITY,

    -- ── 트래픽소스 (session_traffic_source_last_click 승격) ─────────────────────
    -- last-click 한정. first-touch(traffic_source)·collected 는 어트리뷰션 모델·grain 이
    -- 달라 제외한다(설계문서 07 §7-B · 혼재 시 DIM_GA_SOURCE fan-out).
    -- 센티넬 NULLIF 처리. 단 DEFAULT_CHANNEL_GROUP 은 정규화 금지(정상 라벨).
    NULLIF(NULLIF(f.stlc:manual_campaign:source::STRING,
        '(not set)'), '(direct)')                                AS UTM_SOURCE,
    NULLIF(NULLIF(NULLIF(f.stlc:manual_campaign:medium::STRING,
        '(not set)'), '(none)'), '(direct)')                     AS UTM_MEDIUM,
    NULLIF(f.stlc:manual_campaign:campaign_name::STRING,
        '(not set)')                                             AS UTM_CAMPAIGN,
    NULLIF(f.stlc:manual_campaign:content::STRING,
        '(not set)')                                             AS UTM_CONTENT,
    NULLIF(f.stlc:manual_campaign:term::STRING,
        '(not set)')                                             AS UTM_TERM,
    CONCAT_WS(' / ',
        NULLIF(NULLIF(f.stlc:manual_campaign:source::STRING,
            '(not set)'), '(direct)'),
        NULLIF(NULLIF(NULLIF(f.stlc:manual_campaign:medium::STRING,
            '(not set)'), '(none)'), '(direct)'))                AS SOURCE_MEDIUM,
    f.stlc:cross_channel_campaign:source::STRING                 AS XCHAN_SOURCE,
    f.stlc:cross_channel_campaign:medium::STRING                 AS XCHAN_MEDIUM,
    f.stlc:cross_channel_campaign:campaign_name::STRING          AS XCHAN_CAMPAIGN,
    f.stlc:cross_channel_campaign:default_channel_group::STRING  AS DEFAULT_CHANNEL_GROUP,

    -- ── 원천 계보 (설계문서 07 §「🟠 예정」 전제③) ──────────────────────────────
    -- BATCH_ORDERING_ID 는 PK 에서 내려왔지만 컬럼으로는 보존한다(2024 상반기 NULL).
    f.batch_ordering_id                                          AS BATCH_ORDERING_ID,
    f.src_table                                                  AS SRC_TABLE,
    f.src_file_name                                              AS SRC_FILE_NAME,
    f.bronze_load_ts                                             AS BRONZE_LOAD_TS,

    -- ── 공통감사 5 ────────────────────────────────────────────────────────────
    'GA4'                             AS DW_SOURCE_SYSTEM,
    'BRONZE_BIGQUERY.EVENTS'          AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()               AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()               AS DW_UPDATE_TS,
    NULL                              AS DW_BATCH_ID
FROM flat f
