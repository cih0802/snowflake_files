-- =============================================================================
-- Purpose    : GA4 인구통계 일 팩트 (1행 = 일 × 기기 × 성별 × 연령대) · 🆕 [2026-10-08 O213-F Y3-F]
-- Target     : GOLD.FACT_GA4_DEMOGRAPHIC (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref GA4_USER_DEMOGRAPHIC
-- Issue      : O213-F
-- =============================================================================
-- FACT_GA4_DEMOGRAPHIC: GA4 인구통계 일 팩트 (1행 = 일 × 기기 × 성별 × 연령대) · [2026-10-08 O213-F Y3-F]
-- grain: DATE_SK × DEVICE_CATEGORY × USER_GENDER × USER_AGE_BRACKET (원천 SILVER.GA4_USER_DEMOGRAPHIC 과 1:1)
-- WARN: GA4 Data API 집계값이다 — 이벤트 원천(BIGQUERY_*)과 정의·모수가 달라 세션수가 일치하지 않는다(합산·대조 금지).
-- WARN: TOTAL_USERS·NEW_USERS 비가산(grain 단위 고유값) — 상위 축 합산 시 중복 계상 · SESSIONS 만 가산.


select
    COALESCE(CASE WHEN EVENT_DT BETWEEN '1945-01-01' AND '2145-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(EVENT_DT, 'YYYYMMDD')) END, 0)     as DATE_SK,
    DEVICE_CATEGORY,
    USER_GENDER,
    USER_AGE_BRACKET,
    SESSIONS,
    TOTAL_USERS,
    NEW_USERS,
    'GA4'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID
from GN_DW.SILVER.GA4_USER_DEMOGRAPHIC