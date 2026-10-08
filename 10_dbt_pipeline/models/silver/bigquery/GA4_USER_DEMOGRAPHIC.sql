-- GA4_USER_DEMOGRAPHIC: GA4 인구통계 일 집계 (1행 = 일 × 기기 × 성별 × 연령대) · 🆕 [2026-10-08 O213-F Y3-F]
-- Co-authored with CoCo
-- 원천 BRONZE_GA4.GA4_USER_DEMOGRAPHIC(GA4 Data API · 전 컬럼 TEXT) → 타입만 확정. 값 가공 없음(R2-7).
--   실측: 46,143행 · grain 중복 0 · 지표 숫자 변환 실패 0 · 2022-12-27~.
-- 🔴 TOTAL_USERS·NEW_USERS 는 API 가 grain 단위로 낸 고유 사용자수다 — 상위 축(월·성별 전체 등)으로
--    다시 합하면 중복 계상된다(비가산). SESSIONS 만 가산이다.
-- 🔴 'unknown' 은 GA4 가 성별·연령을 추정하지 못한 버킷(원값 보존 · 결측 아님).
-- pre-hook = silver_purge 기본(TRUNCATE) · 전량 재적재.
{{ config(materialized='incremental') }}

select
    TO_DATE(DATE, 'YYYYMMDD')                    as EVENT_DT,
    CAST(DEVICE_CATEGORY AS VARCHAR(20))         as DEVICE_CATEGORY,
    CAST(USER_GENDER AS VARCHAR(20))             as USER_GENDER,
    CAST(USER_AGE_BRACKET AS VARCHAR(20))        as USER_AGE_BRACKET,
    try_to_number(SESSIONS)                      as SESSIONS,
    try_to_number(TOTAL_USERS)                   as TOTAL_USERS,
    try_to_number(NEW_USERS)                     as NEW_USERS,
    CAST('GA4' AS VARCHAR(16777216))                               as DW_SOURCE_SYSTEM,
    CAST('BRONZE_GA4.GA4_USER_DEMOGRAPHIC' AS VARCHAR(16777216))   as DW_SOURCE_TABLE,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)   as DW_LOAD_TS,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)   as DW_UPDATE_TS,
    NULL                                         as DW_BATCH_ID
from {{ source('bronze_ga4', 'GA4_USER_DEMOGRAPHIC') }}
