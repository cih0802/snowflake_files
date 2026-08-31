-- GA4_EVENT: 이벤트 팩트 소스 (07 §5-A 세션 채움 2단계 CTE), 정본 09 STEP6.
-- Co-authored with CoCo
--
-- 🔄 [2026-08-19 O87] 소스 전환 — ga4_union_shards + LATERAL FLATTEN → ref('BIGQUERY_REFINED_DATA').
--    FLATTEN·param 승격·VARIANT 경로 추출·DEVICE_TYPE 파생은 전부 기반 테이블로 이동했다.
--    이 모델에 남은 고유 로직은 **세션 채움(session-fill) 2단계 CTE** 하나다.
-- 🔄 [2026-08-21] BIGQUERY_REFINED_DATA 가 외부 Python 적재로 전환되며 파생을 잃었다 —
--    신설 `GA4_BASIC`(dbt) 이 그 파생을 되살리므로 ref() 로 되돌린다(source() → ref('GA4_BASIC')).
--
-- 🟢 GA4-PK-1 해소 — PK 4번째 키를 BATCH_ORDERING_ID → EVENT_SEQ 로 교체(NOT NULL 위반 해소).
--    종전 PK 는 2024-01-01~07-18 · 199일 · 48,862,926행(17.10%)을 NOT NULL 위반으로 배제했다.
--    EVENT_SEQ 는 GA4_BASIC 이 3키 내에서 BATCH_EVENT_INDEX+EVENT_BUNDLE_SEQUENCE_ID 순으로
--    부여한 surrogate 다. 🔴 「손실 0」은 아니다 — 두 컬럼으로도 2025-06 실측 8.66% 중복이
--    남고(값 자체가 원천에서 중복 · 미결 GA4-SEQ-1), SRC_FILE_NAME 계보는 외부 적재에 없다.
--    ⚠️ BATCH_ORDERING_ID 는 컬럼으로는 보존한다(2024 상반기 NULL) — 계보·정렬 근거.
--
-- 🟢 GA4-LEN-1 해소 — USER_ID·USER_ID_FILLED VARCHAR(10) → VARCHAR(64) + ID_SCHEME 분류축 승계.
--    길이 확장만 하면 IDENTITY_MEMBER_XREF 매칭 분모에 비회원 ID(app-·이메일·'null')가 섞여
--    채움률이 조용히 왜곡된다 ⇒ ID_SCHEME 을 함께 노출한다(설계문서 07 §7-B).
--
-- 🔴 세션 채움의 범위 경계 — sess CTE 는 **기반 테이블 전량**을 본다(범위 제한 없음).
--    근거: 세션은 자정을 넘고 GA4 는 D+3 소급 수정된다 ⇒ 범위로 자르면 세션이 경계에서 끊겨
--    CONFLICT·부분채움 오류가 난다(설계문서 07 §5-A ⚠️ 항목). 반면 최종 SELECT 는
--    적재 범위(pre-hook DELETE 와 동일 범위)로 제한해 멱등성을 지킨다.
--    n_id >= 2 = CONFLICT(미채움). 원본 USER_ID 는 불변 보존.
-- 🔴 pre-hook 은 여기서 선언하지 않는다 — `macros/silver_purge.sql` 이 이 모델을 range 모델로
--    인식해 **TRUNCATE 대신 범위 DELETE** 를 낸다(dbt hook 누적 사고 방지 · dbt_project.yml 참조).
--    ⚠️ 모델명을 바꾸면 `silver_purge.RANGED_MODELS` 도 함께 고쳐야 한다.

WITH base AS (
    SELECT * FROM GN_DW.SILVER.GA4_BASIC
),
-- 세션 단위 신원 집계 — 🔴 Snowflake 는 COUNT(DISTINCT x) OVER(...) 를 지원하지 않는다.
--    MAX(user_id) OVER(파티션) 단독으로 채우면 CONFLICT 세션이 조용히 오귀속된다
--    ⇒ 반드시 2단계(집계 CTE → LEFT JOIN). 설계문서 07 §5-A 「구현 주의」.
--    세션 키는 복합(GA_SESSION_KEY = user_pseudo_id ∥ '-' ∥ ga_session_id).
sess AS (
    SELECT
        GA_SESSION_KEY,
        COUNT(DISTINCT USER_ID) AS n_id,
        MAX(USER_ID)            AS sess_uid
    FROM base
    WHERE GA_SESSION_KEY IS NOT NULL
    GROUP BY GA_SESSION_KEY
)
SELECT
    b.USER_PSEUDO_ID                                             AS USER_PSEUDO_ID,
    b.EVENT_TIMESTAMP                                            AS EVENT_TIMESTAMP,
    b.EVENT_NAME                                                 AS EVENT_NAME,
    b.EVENT_SEQ                                                  AS EVENT_SEQ,
    b.EVENT_DATE                                                 AS EVENT_DATE,
    b.EVENT_DT                                                   AS EVENT_DT,
    b.EVENT_TS                                                   AS EVENT_TS,
    b.USER_ID                                                    AS USER_ID,
    b.ID_SCHEME                                                  AS ID_SCHEME,
    b.GA_SESSION_ID                                              AS GA_SESSION_ID,
    b.GA_SESSION_NUMBER                                          AS GA_SESSION_NUMBER,
    b.GA_SESSION_KEY                                             AS GA_SESSION_KEY,
    CASE WHEN b.USER_ID IS NOT NULL      THEN b.USER_ID
         WHEN b.GA_SESSION_KEY IS NULL   THEN NULL
         WHEN s.n_id = 1                 THEN s.sess_uid
         ELSE NULL END                                           AS USER_ID_FILLED,
    CASE WHEN b.USER_ID IS NOT NULL      THEN 'DIRECT'
         WHEN b.GA_SESSION_KEY IS NULL   THEN 'UNRESOLVED'
         WHEN s.n_id = 1                 THEN 'SESSION_FILL'
         WHEN s.n_id >= 2                THEN 'CONFLICT'
         ELSE 'UNRESOLVED' END                                   AS ID_RESOLUTION,
    b.SESSION_ENGAGED                                            AS SESSION_ENGAGED,
    b.ENGAGEMENT_TIME_MSEC                                       AS ENGAGEMENT_TIME_MSEC,
    b.PAGE_LOCATION                                              AS PAGE_LOCATION,
    b.PAGE_TITLE                                                 AS PAGE_TITLE,
    b.PAGE_REFERRER                                              AS PAGE_REFERRER,
    b.EVENT_CATEGORY                                             AS EVENT_CATEGORY,
    b.EVENT_ACTION                                               AS EVENT_ACTION,
    b.EVENT_LABEL                                                AS EVENT_LABEL,
    b.PERCENT_SCROLLED                                           AS PERCENT_SCROLLED,
    b.LINK_URL                                                   AS LINK_URL,
    b.LINK_TEXT                                                  AS LINK_TEXT,
    b.DEVICE_TYPE                                                AS DEVICE_TYPE,
    b.DEVICE_CATEGORY                                            AS DEVICE_CATEGORY,
    b.OS                                                         AS OS,
    b.GEO_COUNTRY                                                AS GEO_COUNTRY,
    b.GEO_CITY                                                   AS GEO_CITY,
    b.UTM_SOURCE                                                 AS UTM_SOURCE,
    b.UTM_MEDIUM                                                 AS UTM_MEDIUM,
    b.UTM_CAMPAIGN                                               AS UTM_CAMPAIGN,
    b.DEFAULT_CHANNEL_GROUP                                      AS DEFAULT_CHANNEL_GROUP,
    b.PLATFORM                                                   AS PLATFORM,
    b.IS_ACTIVE_USER                                             AS IS_ACTIVE_USER,
    b.BATCH_ORDERING_ID                                          AS BATCH_ORDERING_ID,
    NULL                                                          AS SRC_TABLE,
    NULL                                                          AS SRC_FILE_NAME,
    'GA4'                             AS DW_SOURCE_SYSTEM,
    'SILVER.GA4_BASIC'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()               AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()               AS DW_UPDATE_TS,
    NULL                              AS DW_BATCH_ID
FROM base b
LEFT JOIN sess s
    ON b.GA_SESSION_KEY IS NOT NULL
   AND s.GA_SESSION_KEY = b.GA_SESSION_KEY
-- 적재 범위 = pre-hook DELETE 범위와 동일해야 멱등이다(둘이 어긋나면 행이 남거나 사라진다).
-- 🔴 [2026-08-19 O88] 그 「동일함」을 사람이 맞추지 않도록 술어를 매크로로 외부화했다 —
--    정의 지점은 `macros/ga4_range_predicate.sql` 하나다. 여기에 술어를 다시 쓰지 마라.
WHERE (
    (b.EVENT_DT >= TO_DATE('2024-06-01') AND b.EVENT_DT <= TO_DATE('2024-06-30'))
    OR (b.EVENT_DT >= TO_DATE('2025-06-01') AND b.EVENT_DT <= TO_DATE('2025-06-30'))
    OR (b.EVENT_DT >= TO_DATE('2026-06-01') AND b.EVENT_DT <= TO_DATE('2026-06-30'))
  )