-- FACT_GA4_DEMOGRAPHIC: GA4 인구통계 일 팩트 (1행 = 일 × 기기 × 성별 × 연령대) · 🆕 [2026-10-08 O213-F Y3-F]
-- Co-authored with CoCo
-- grain: DATE_SK × DEVICE_CATEGORY × USER_GENDER × USER_AGE_BRACKET (원천 SILVER.GA4_USER_DEMOGRAPHIC 과 1:1)
-- 🔴 GA4 Data API 집계값이다 — 이벤트 원천(BIGQUERY_*)과 정의·모수가 달라 세션수가 일치하지 않는다(합산·대조 금지).
-- 🔴 TOTAL_USERS·NEW_USERS 비가산(grain 단위 고유값) — 상위 축 합산 시 중복 계상 · SESSIONS 만 가산.
{{ config(
    tags=['gold_ready']
) }}

select
    COALESCE({{ date_sk('EVENT_DT') }}, 0)     as DATE_SK,
    DEVICE_CATEGORY,
    USER_GENDER,
    USER_AGE_BRACKET,
    SESSIONS,
    TOTAL_USERS,
    NEW_USERS,
    {{ gold_meta('GA4') }}
from {{ ref('GA4_USER_DEMOGRAPHIC') }}
