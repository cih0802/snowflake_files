-- FACT_SEARCH_CONSOLE: 검색 노출·클릭 일 팩트 (1행 = 일 × 검색어 × 페이지 × 국가 × 기기) · 🆕 [2026-10-08 O213-F Y3-F]
-- Co-authored with CoCo
-- grain: DATE_SK × QUERY × PAGE × COUNTRY × DEVICE (원천 SILVER.SEARCH_CONSOLE_DATA 와 1:1 · 5키 중복 0 실측)
-- 🔴 CTR·POSITION 은 행 단위 비율/평균 — 합산 금지. 상위 집계 CTR = SUM(CLICKS)/SUM(IMPRESSIONS),
--    평균순위 = SUM(POSITION_X_IMPRESSIONS)/SUM(IMPRESSIONS)(노출 가중) ⇒ 가중용 곱을 여기서 미리 만든다.
-- 🔴 GA4(BIGQUERY_*) 와 다른 원천(구글 검색 결과 노출)이다 — 클릭수 ≠ 유입 세션수(대조 금지).
{{ config(
    tags=['gold_ready']
) }}

select
    COALESCE({{ date_sk('EVENT_DT') }}, 0)     as DATE_SK,
    QUERY,
    PAGE,
    COUNTRY,
    DEVICE,
    CLICKS,
    IMPRESSIONS,
    CTR,
    POSITION,
    POSITION * IMPRESSIONS                     as POSITION_X_IMPRESSIONS,
    {{ gold_meta('GSC') }}
from {{ ref('SEARCH_CONSOLE_DATA') }}
