-- GA4 BigQuery export CSV를 GN_DW.BRONZE_GA4로 적재하는 스테이지→브론즈 쿼리
-- Co-authored with CoCo
/*
================================================================================
  BRONZE_GA4 — Stage → Bronze 적재 쿼리
  스테이지  : SANDBOX.TOOLS.GA4_RAW
  목적 스키마: GN_DW.BRONZE_GA4
  작성일   : 2026-07-02
  실적재 이력: EVENTS_20260501 (1,000행, 에러 0건, 2026-07-02 완료)
--------------------------------------------------------------------------------
  파일 구성
  ─────────────────────────────────────────────────────────────────────────────
  STEP 0: BRONZE_GA4 스키마 생성 (이미 있으면 스킵)
  STEP 1: FILE FORMAT 생성 (COPY INTO 에 사용)
  STEP 2: Bronze 테이블 DDL (EVENTS_YYYYMMDD)
  STEP 3: COPY INTO (Stage → Bronze)
  STEP 4: 검증 쿼리

  date-shard 운영 방법
  ─────────────────────────────────────────────────────────────────────────────
  GA4 원천은 날짜별 테이블(EVENTS_YYYYMMDD) 로 분리 적재한다.
  새 날짜 데이터 입고 시 STEP 2~3 의 날짜 부분만 교체하여 반복 실행.
  예) EVENTS_20260502 적재 시:
      - STEP 2: 테이블명을 EVENTS_20260502 로 변경
      - STEP 3: 파일 경로를 해당 날짜 CSV 로 변경

  컬럼 구조 (30개 · 2026-07-02 실측 확정)
  ─────────────────────────────────────────────────────────────────────────────
  스칼라(16): event_date, event_timestamp, event_name, event_previous_timestamp,
              event_value_in_usd, event_bundle_sequence_id,
              event_server_timestamp_offset, user_id, user_pseudo_id,
              user_first_touch_timestamp, stream_id, platform,
              is_active_user, batch_event_index, batch_page_id, batch_ordering_id
  VARIANT(14): event_params, privacy_info, user_properties, user_ltv,
               device, geo, app_info, traffic_source, event_dimensions,
               ecommerce, items, collected_traffic_source,
               session_traffic_source_last_click, publisher

  주의
  ─────────────────────────────────────────────────────────────────────────────
  - 원본은 GA4 BigQuery export JSON → CSV 변환본.
    중첩 필드(event_params 등)는 CSV 내 JSON 문자열로 삽입되어 있음.
    Snowflake COPY INTO 가 VARIANT 컬럼으로 적재하면서 자동 파싱. (실증 완료)
  - 스펙 §3.14 의 event_original_occurrence_timestamp 는
    이 CSV export 에 포함되지 않음. (Q-GA6)
  - collected_traffic_source / privacy_info 동의필드는 표본에서 NULL.
    컬럼은 유지하되 값 의존 로직 금지.
  - ⚠️ [커버리지] user_id 채움률 약 4.2%(전수 12,120/287,025·식별 1,290명·익명 95.8%).
    user_pseudo_id는 별도 익명 ID → 회원단위 GA 지표는 세션 스티칭 없이 극히 부분적.
    회원 조인(GA4_IDENTITY) 결과를 전수로 단정하지 말 것(#81·C-Q2·SF-biz 커버리지 경고).
  - ⚠️ [샤드 범위] 본 스크립트는 EVENTS_YYYYMMDD **1일 샤드** 적재이며 전체기간이 아님.
    [2026-07-13 실측] 실제 `BRONZE_GA4."events_20260501"` = **287,025행**(전체 1일 샤드; 표본 아님, 소문자 샤드명).
    기간 분석은 반드시 전체 샤드 UNION 후 수행.
================================================================================
*/


-- ============================================================================
-- STEP 0: BRONZE_GA4 스키마 생성
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_GA4
    COMMENT = '원천 데이터 적재 레이어 (GA4 BigQuery export CSV)';


-- ============================================================================
-- STEP 1: FILE FORMAT 생성
--   - CSV + 헤더 1행 스킵
--   - 따옴표로 감싼 JSON 문자열 처리 (FIELD_OPTIONALLY_ENCLOSED_BY)
--   - GA4 에서 자주 쓰는 NULL 표현값 일괄 처리
-- ============================================================================
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_GA4.GA4_CSV_FMT
    TYPE                        = 'CSV'
    SKIP_HEADER                 = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                     = ('NULL', 'null', 'None', '')
    EMPTY_FIELD_AS_NULL         = TRUE
    COMMENT = 'GA4 BigQuery export CSV 전용 포맷';


-- ============================================================================
-- STEP 2: Bronze 테이블 DDL
--   ※ 새 날짜 적재 시 테이블명의 날짜 부분(20260501)만 교체
-- ============================================================================
CREATE OR REPLACE TABLE GN_DW.BRONZE_GA4.EVENTS_20260501 (
    -- ── 스칼라 컬럼 ──────────────────────────────────────────────────────────
    event_date                          VARCHAR(8),         -- YYYYMMDD 문자열
    event_timestamp                     NUMBER,             -- UTC 마이크로초
    event_name                          VARCHAR(200),
    event_previous_timestamp            NUMBER,
    event_value_in_usd                  FLOAT,
    event_bundle_sequence_id            NUMBER,
    event_server_timestamp_offset       NUMBER,
    user_id                             VARCHAR(500),       -- CRM 회원번호 추정 (Q1 미확정)
    user_pseudo_id                      VARCHAR(200),
    user_first_touch_timestamp          NUMBER,
    stream_id                           VARCHAR(50),
    platform                            VARCHAR(50),        -- WEB / ANDROID / IOS
    is_active_user                      BOOLEAN,
    batch_event_index                   NUMBER,
    batch_page_id                       NUMBER,
    batch_ordering_id                   NUMBER,
    -- ── VARIANT 컬럼 (중첩 JSON → Snowflake 자동 파싱) ──────────────────────
    event_params                        VARIANT,            -- ARRAY — LATERAL FLATTEN 대상
    privacy_info                        VARIANT,            -- 동의 정보 (표본 NULL · Q-GA6)
    user_properties                     VARIANT,            -- ARRAY
    user_ltv                            VARIANT,
    device                              VARIANT,            -- device:category / os / browser 등
    geo                                 VARIANT,            -- geo:country / region / city
    app_info                            VARIANT,
    traffic_source                      VARIANT,            -- first-touch (보조)
    event_dimensions                    VARIANT,
    ecommerce                           VARIANT,
    items                               VARIANT,            -- ARRAY
    collected_traffic_source            VARIANT,            -- event-scoped UTM (표본 NULL · Q-GA6)
    session_traffic_source_last_click   VARIANT,            -- session/last-click → GA4 UI 일치
    publisher                           VARIANT
)
COMMENT = 'GA4 원천 이벤트 (2026-05-01) — Stage 적재본. JSON 중첩 필드는 VARIANT 보존.';
/*
  ※ 신규 날짜 테이블 생성 시 위 DDL 을 복사해서 테이블명만 교체.
     예) EVENTS_20260502, EVENTS_20260503 …
     컬럼 구조 변경이 발생하면 이 파일을 함께 업데이트할 것.
*/


-- ============================================================================
-- STEP 3: COPY INTO — Stage → Bronze
--   ※ 새 날짜 적재 시 ① 테이블명 ② 파일 경로만 교체
-- ============================================================================
COPY INTO GN_DW.BRONZE_GA4.EVENTS_20260501           -- ① 테이블명 교체
FROM @SANDBOX.TOOLS.GA4_RAW/temp_2026-07-02-0929.csv -- ② 파일 경로 교체
FILE_FORMAT = (
    FORMAT_NAME = GN_DW.BRONZE_GA4.GA4_CSV_FMT
)
ON_ERROR = 'CONTINUE';
/*
  ON_ERROR = 'CONTINUE' : 파싱 오류 행은 건너뛰고 적재 계속.
  오류가 발생하면 STEP 4 검증 쿼리로 errors_seen 확인 후
  원인 파악 전까지 해당 행은 Silver 에 사용하지 말 것.

  [전체 날짜 범위 적재 예시 — 파일이 여러 개일 때]
  COPY INTO GN_DW.BRONZE_GA4.EVENTS_20260502
  FROM @SANDBOX.TOOLS.GA4_RAW/
  PATTERN = '.*20260502.*\\.csv'
  FILE_FORMAT = (FORMAT_NAME = GN_DW.BRONZE_GA4.GA4_CSV_FMT)
  ON_ERROR = 'CONTINUE';
*/


-- ============================================================================
-- STEP 4: 검증 쿼리
-- ============================================================================

-- 4-1. COPY 결과 확인 (rows_loaded / errors_seen)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME   => 'EVENTS_20260501',
    START_TIME   => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY last_load_time DESC
LIMIT 5;

-- 4-2. 행 수 · 기본 통계
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(user_id)                  AS user_id_filled,
    COUNT(DISTINCT user_pseudo_id)  AS distinct_pseudo_id,
    COUNT(DISTINCT event_name)      AS distinct_events,
    MIN(TO_TIMESTAMP(event_timestamp / 1000000)) AS earliest_ts,
    MAX(TO_TIMESTAMP(event_timestamp / 1000000)) AS latest_ts
FROM GN_DW.BRONZE_GA4.EVENTS_20260501;

-- 4-3. VARIANT 파싱 확인 (event_params 첫 번째 키·값)
SELECT
    event_name,
    event_params[0]:key::STRING         AS first_param_key,
    event_params[0]:value:string_value::STRING AS first_param_str,
    event_params[0]:value:int_value::NUMBER    AS first_param_int
FROM GN_DW.BRONZE_GA4.EVENTS_20260501
WHERE event_params IS NOT NULL
LIMIT 5;

-- 4-4. 비어있는 VARIANT 컬럼 채움율 점검
SELECT
    COUNT(session_traffic_source_last_click)    AS sts_filled,
    COUNT(traffic_source)                       AS ts_filled,
    COUNT(collected_traffic_source)             AS cts_filled,   -- 표본 0 정상
    COUNT(device)                               AS device_filled,
    COUNT(geo)                                  AS geo_filled,
    COUNT(privacy_info)                         AS privacy_filled -- 표본 0 정상
FROM GN_DW.BRONZE_GA4.EVENTS_20260501;
