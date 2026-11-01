-- GN_DW DB·BRONZE 스키마 생성 및 SANDBOX.TOOLS.BRONZE_RAW 스테이지 CSV 4종 적재.
-- Co-authored with CoCo
/*
================================================================================
  BRONZE RAW 전체 적재 — GN_DW 신규 구성
  스테이지  : SANDBOX.TOOLS.BRONZE_RAW/bronze_raw/
  목적 DB   : GN_DW
  작성일    : 2026-07-03
--------------------------------------------------------------------------------
  파일 (2026-07-07 정합 재샘플: `CRM_`/`GA4_` 접두 = 회원번호 1985xxx 동일 슬라이스 — 마스터↔상태이력 100% 정합)
  ─────────────────────────────────────────────────────────────────────────────
  [GA4]
    GA4_events_20260501_1000.csv          → GN_DW.BRONZE_GA4.EVENTS_20260501   (정합 재샘플)
    # (구) events_20260501_1000.csv · events_20260501_userid_1000.csv — 비정합 샘플, 대체됨
  [CRM]
    CRM_TM_MM_FDRM_MBER_INFO_1000.csv     → GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO       (정합 재샘플)
    TM_MM_ONCE_MBER_INFO_1000.csv         → GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO       (일시회원, 기존)
    CRM_TH_MM_FDRM_MBER_STNG_DTLS_1000.csv → GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS (SCD2 원천, 정합 재샘플)
  ─────────────────────────────────────────────────────────────────────────────
  STEP 0 : DB 생성
  STEP 1 : 스키마 생성 (BRONZE_GA4 / BRONZE_CRM)
  STEP 2 : 파일 포맷 생성
  STEP 3 : 테이블 DDL
  STEP 4 : COPY INTO
  STEP 5 : 검증
================================================================================
*/


-- ============================================================================
-- STEP 0: GN_DW 데이터베이스 생성
-- ============================================================================
CREATE DATABASE IF NOT EXISTS GN_DW
    COMMENT = 'GN_DW 분석 DW (BRONZE → SILVER → GOLD)';


-- ============================================================================
-- STEP 1: 스키마 생성
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_GA4
    COMMENT = '원천 데이터 적재 레이어 — GA4 BigQuery export CSV';

CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_CRM
    WITH MANAGED ACCESS
    COMMENT = '원천 데이터 적재 레이어 — CRM';


-- ============================================================================
-- STEP 2: 파일 포맷
-- ============================================================================

-- GA4: CSV + VARIANT(JSON 문자열) 처리
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_GA4.GA4_CSV_FMT
    TYPE                         = 'CSV'
    PARSE_HEADER                 = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                      = ('NULL', 'null', 'None', '')
    EMPTY_FIELD_AS_NULL          = TRUE
    COMMENT = 'GA4 BigQuery export CSV 전용 포맷 (PARSE_HEADER 기반 컬럼명 매핑)';

-- CRM: 단순 CSV (VARIANT 없음)
CREATE OR REPLACE FILE FORMAT GN_DW.BRONZE_CRM.CRM_CSV_FMT
    TYPE                         = 'CSV'
    SKIP_HEADER                  = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                      = ('NULL', 'null', 'None', '')
    EMPTY_FIELD_AS_NULL          = TRUE
    DATE_FORMAT                  = 'AUTO'
    TIMESTAMP_FORMAT             = 'AUTO'
    COMMENT = 'CRM 원천 CSV 전용 포맷';


-- ============================================================================
-- STEP 3: 테이블 DDL
-- ============================================================================

-- [GA4] EVENTS_20260501 (컬럼 30개 · 스칼라 16 + VARIANT 14)
CREATE OR REPLACE TABLE GN_DW.BRONZE_GA4.EVENTS_20260501 (
    event_date                          VARCHAR(8),
    event_timestamp                     NUMBER,
    event_name                          VARCHAR(200),
    event_previous_timestamp            NUMBER,
    event_value_in_usd                  FLOAT,
    event_bundle_sequence_id            NUMBER,
    event_server_timestamp_offset       NUMBER,
    user_id                             VARCHAR(500),  -- ⚠️ 채움률 약 4.2%(전수 12,120/287,025·식별 1,290명). 회원단위 GA 지표는 부분적 — 전수 단정 금지
    user_pseudo_id                      VARCHAR(200),  -- 익명 ID(user_id와 별개). 세션 스티칭 없이는 회원 조인 불가
    user_first_touch_timestamp          NUMBER,
    stream_id                           VARCHAR(50),
    platform                            VARCHAR(50),
    is_active_user                      BOOLEAN,
    batch_event_index                   NUMBER,
    batch_page_id                       NUMBER,
    batch_ordering_id                   NUMBER,
    event_params                        VARIANT,
    privacy_info                        VARIANT,
    user_properties                     VARIANT,
    user_ltv                            VARIANT,
    device                              VARIANT,
    geo                                 VARIANT,
    app_info                            VARIANT,
    traffic_source                      VARIANT,
    event_dimensions                    VARIANT,
    ecommerce                           VARIANT,
    items                               VARIANT,
    collected_traffic_source            VARIANT,
    session_traffic_source_last_click   VARIANT,
    publisher                           VARIANT
)
COMMENT = 'GA4 원천 이벤트 (2026-05-01) — BRONZE_RAW 적재본';

-- [CRM] TM_MM_FDRM_MBER_INFO (정기회원 마스터)
CREATE OR REPLACE TABLE GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO (
    MBER_NO             VARCHAR(10),
    MBER_DIV_CD         VARCHAR(3),
    CPR_DIV_CD          VARCHAR(3),
    SLRCLD_LRR_CD       VARCHAR(3),
    MOBLPHON_STAT_CD    VARCHAR(3),
    TSTM_DIV_CD         NUMBER(10,0),
    ETC_TSTM_DIV_CD     NUMBER(10,0),
    ETC_CTTPC_REL_CD    VARCHAR(3),
    ETC_CTTPC_STAT_CD   VARCHAR(3),
    EMAIL_STAT_CD       VARCHAR(3),
    PSTMTR_RECPTN_CD    VARCHAR(100),
    EMAIL_RECPTN_CD     VARCHAR(100),
    CHRCTR_RECPTN_YN    VARCHAR(1),
    BL_ENTRPS_NO        NUMBER(19,0),
    SPECL_MNG_CD1       VARCHAR(3),
    SPECL_MNG_CD2       VARCHAR(3),
    TNI_CU_BL_NO        NUMBER(19,0),
    CMPGN_CD            VARCHAR(20),
    MBER_STAT_CD        VARCHAR(3),
    RELATNSP_DIV_CD     VARCHAR(3),
    ACT_DEPT_CD         VARCHAR(10),
    HMPG_ID             VARCHAR(30),
    JOIN_PATH_CD        VARCHAR(3),
    CTI_SYNCHRN_DIV_CD  VARCHAR(3),
    STDR_DE             DATE,
    FRST_REGIST_DT      TIMESTAMP_NTZ(9),
    REGIST_DEPT_CD      VARCHAR(10),
    FRST_RGSTR_ID       VARCHAR(30),
    SEX                 VARCHAR(2),
    _LOAD_DT            TIMESTAMP_NTZ(9),
    _BATCH_ID           VARCHAR(50)
)
COMMENT = 'CRM 정기회원 마스터 (TM_MM_FDRM_MBER_INFO) — BRONZE_RAW 적재본';

-- [CRM] TM_MM_ONCE_MBER_INFO (일시회원 마스터)
CREATE OR REPLACE TABLE GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO (
    ONCE_MBER_NO            VARCHAR(10),
    MBER_DIV_CD             VARCHAR(3),
    CPR_DIV_CD              VARCHAR(3),
    SEX                     VARCHAR(2),
    TSTM_DIV_CD             NUMBER(10,0),
    ETC_TSTM_DIV_CD         NUMBER(10,0),
    REL_CD                  VARCHAR(3),
    ENTRPS_NM               VARCHAR(200),
    HMPG_ID                 VARCHAR(30),
    PSTMTR_RECPTN_YN        VARCHAR(1),
    EMAIL_RECPTN_YN         VARCHAR(1),
    CHRCTR_RECPTN_YN        VARCHAR(1),
    FDRM_MBER_TRNSFER_FG    BOOLEAN,
    SPECL_MNG_CD1           VARCHAR(100),
    SPECL_MNG_CD2           VARCHAR(100),
    TNI_CU_BL_NO            NUMBER(19,0),
    CTI_SYNCHRN_DIV_CD      VARCHAR(3),
    FRST_REGIST_DT          TIMESTAMP_NTZ(9),
    REGIST_DEPT_CD          VARCHAR(10),
    FRST_RGSTR_ID           VARCHAR(100),
    _LOAD_DT                TIMESTAMP_NTZ(9),
    _BATCH_ID               VARCHAR(50)
)
COMMENT = 'CRM 일시회원 마스터 (TM_MM_ONCE_MBER_INFO) — BRONZE_RAW 적재본';

-- [CRM] TH_MM_FDRM_MBER_STNG_DTLS (정기회원 상태변경내역 — DIM_MEMBER SCD2 원천)
-- CSV 컬럼순서: MBER_NO, SER_NO, BF_STAT_CD, CHN_STAT_CD, FRST_RGSTR_ID, FRST_REGIST_DT, _LOAD_DT, _BATCH_ID
CREATE OR REPLACE TABLE GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS (
    MBER_NO         VARCHAR(10),
    SER_NO          NUMBER(38,0),
    BF_STAT_CD      VARCHAR(3),
    CHN_STAT_CD     VARCHAR(3),
    FRST_RGSTR_ID   VARCHAR(100),
    FRST_REGIST_DT  TIMESTAMP_NTZ(9),
    _LOAD_DT        TIMESTAMP_NTZ(9),
    _BATCH_ID       VARCHAR(50)
)
COMMENT = 'CRM 정기회원 상태변경내역 (TH_MM_FDRM_MBER_STNG_DTLS) — BRONZE_RAW 적재본, DIM_MEMBER SCD2 원천';


-- ============================================================================
-- STEP 4: COPY INTO
-- ============================================================================

-- [GA4] 정합 재샘플 (2026-07-07): 회원 1985xxx 동일 슬라이스 단일 파일
-- (구) events_20260501_1000.csv + events_20260501_userid_1000.csv 는 비정합 샘플이라 대체됨.
-- ⚠️ [범위] 본 COPY는 `GA4_events_20260501_1000.csv`(1,000행 정합 표본)를 적재.
--    단, [2026-07-13 실측] 현재 물리 `BRONZE_GA4."events_20260501"` = **287,025행**(전체 1일 샤드) —
--    이 스크립트 이후 전량(full-shard) 적재가 별도 수행된 상태. 기간 분석은 전체 샤드 UNION 후.
--    user_id 커버리지 4.22%(12,120/287,025·distinct 1,290·pseudo 27,840) 실측 확인(위 DDL 주석 참조).
-- ⚠️ [FILE FORMAT] 본 스크립트의 GA4_CSV_FMT는 PARSE_HEADER + MATCH_BY_COLUMN_NAME 방식.
--    BRONZE_GA4_stage_load_20260702.sql의 동명 포맷(SKIP_HEADER=1·위치기반)과 정의가 상이함.
--    두 스크립트를 함께 실행 시 CREATE OR REPLACE 순서에 따라 적재 방식이 달라지므로 하나로 통일 필요.
COPY INTO GN_DW.BRONZE_GA4.EVENTS_20260501
FROM @SANDBOX.TOOLS.BRONZE_RAW/GA4_events_20260501_1000.csv
FILE_FORMAT = (FORMAT_NAME = GN_DW.BRONZE_GA4.GA4_CSV_FMT)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- [CRM] 정기회원 (정합 재샘플)
COPY INTO GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
FROM @SANDBOX.TOOLS.BRONZE_RAW/CRM_TM_MM_FDRM_MBER_INFO_1000.csv
FILE_FORMAT = (FORMAT_NAME = GN_DW.BRONZE_CRM.CRM_CSV_FMT)
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- [CRM] 일시회원
COPY INTO GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO
FROM @SANDBOX.TOOLS.BRONZE_RAW/TM_MM_ONCE_MBER_INFO_1000.csv
FILE_FORMAT = (FORMAT_NAME = GN_DW.BRONZE_CRM.CRM_CSV_FMT)
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- [CRM] 정기회원 상태변경내역 (2026-07-07 · 정합 재샘플 · DIM_MEMBER SCD2 원천)
COPY INTO GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
FROM @SANDBOX.TOOLS.BRONZE_RAW/CRM_TH_MM_FDRM_MBER_STNG_DTLS_1000.csv
FILE_FORMAT = (FORMAT_NAME = GN_DW.BRONZE_CRM.CRM_CSV_FMT)
ON_ERROR = 'CONTINUE'
FORCE = TRUE;


-- ============================================================================
-- STEP 5: 검증
-- ============================================================================
SELECT 'BRONZE_GA4.EVENTS_20260501'       AS tbl, COUNT(*) AS row_cnt FROM GN_DW.BRONZE_GA4.EVENTS_20260501
UNION ALL
SELECT 'BRONZE_CRM.TM_MM_FDRM_MBER_INFO' AS tbl, COUNT(*) AS row_cnt FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO
UNION ALL
SELECT 'BRONZE_CRM.TM_MM_ONCE_MBER_INFO' AS tbl, COUNT(*) AS row_cnt FROM GN_DW.BRONZE_CRM.TM_MM_ONCE_MBE