-- SEARCH_CONSOLE_DATA: Google Search Console 일 집계 (1행 = 일 × 검색어 × 페이지 × 국가 × 기기) · 🆕 [2026-10-08 O213-F Y3-F]
-- Co-authored with CoCo
-- 원천 BRONZE_GSC.SEARCH_CONSOLE_DATA(byPage 집계) → 값 가공 없음(R2-7). 실측 983,601행 · 5키 중복 0 · 2025-04-08~.
--   🔴 SEARCH_CONSOLE_DATA2 는 읽지 않는다 — 2026-09-08 까지 이 표와 941,298행 전건 일치(기간만 짧은 복사본).
-- 🔴 CTR·POSITION 은 비가산(행 단위 비율·평균순위) — 상위 집계는 SUM(CLICKS)/SUM(IMPRESSIONS) ·
--    노출 가중 평균순위로 다시 계산한다(GOLD/SV 지표가 그렇게 정의한다).
-- 🔴 COUNTRY = ISO 3166-1 alpha-3 소문자 코드(예 kor) · 원천에 라벨 없음 ⇒ 코드 그대로 노출.
-- pre-hook = silver_purge 기본(TRUNCATE) · 전량 재적재.
{{ config(materialized='incremental') }}

select
    DATE                                         as EVENT_DT,
    QUERY,
    PAGE,
    CAST(COUNTRY AS VARCHAR(10))                 as COUNTRY,
    CAST(DEVICE AS VARCHAR(20))                  as DEVICE,
    CLICKS,
    IMPRESSIONS,
    CTR,
    POSITION,
    CAST(RESPONSE_AGGREGATION_TYPE AS VARCHAR(20)) as RESPONSE_AGGREGATION_TYPE,
    CAST('GSC' AS VARCHAR(16777216))                               as DW_SOURCE_SYSTEM,
    CAST('BRONZE_GSC.SEARCH_CONSOLE_DATA' AS VARCHAR(16777216))    as DW_SOURCE_TABLE,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)   as DW_LOAD_TS,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)   as DW_UPDATE_TS,
    NULL                                         as DW_BATCH_ID
from {{ source('bronze_gsc', 'SEARCH_CONSOLE_DATA') }}
