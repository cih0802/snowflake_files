-- =============================================================================
-- Purpose    : [2026-10-14 O225] FACT_AD_PERFORMANCE 는 마케팅캠페인 귀속 전후로 광고행·광고비를 잃거나 복제하지 않아야 한다.
-- Target     : dbt singular test assert_fap_ad_cost_preserved (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref AGENCY_AD_PERFORMANCE, ref FACT_AD_PERFORMANCE
-- Issue      : O225, O225-B
-- =============================================================================
-- [2026-10-14 O225] FACT_AD_PERFORMANCE 는 마케팅캠페인 귀속 전후로 광고행·광고비를 잃거나 복제하지 않아야 한다.
--
-- 무엇을 지키는가: SILVER.AGENCY_AD_PERFORMANCE(원천) ↔ GOLD 팩트의 원천별 행수·광고비 합계(원 단위) 일치.
--   O225 가 UTM 보조 경로(`utm_pick`)를 붙였다 — 그 CTE 가 AD_PERF_DK 당 1행이 아니면 광고비가 복제되고,
--   종전 `HAVING COUNT(DISTINCT …) = 1` 처럼 1:N 을 버리면 행은 남아도 귀속이 0 으로 빠진다.
--   ⇒ 행수·합계 대조(이 파일) + 미매핑 비율 경고(`warn_fap_mktg_unmapped_ratio`) 두 축으로 본다.
--   WARN: 안전장치는 「버리기」가 아니라 「대조」다(작업계획 §15-9).
--
-- 판정: 0행이면 PASS.
{{ config(severity = 'error') }}

with src as (
    -- WARN: [O225-B] 행 단위 ROUND(,2) — GOLD DDL 이 NUMBER(18,2) 라 행마다 반올림 저장된다.
    --   원값 합계와 비교하면 반올림 누적으로 거짓 FAIL(첫 build: VIDEO -5.75원 · DIGITAL +0.51 · REBRDC +0.19원).
    select AD_SOURCE_TYPE, count(*) as N, SUM(ROUND(AD_COST, 2)) as COST
    from {{ ref('AGENCY_AD_PERFORMANCE') }}
    group by 1
),
fct as (
    select AD_SOURCE_TYPE, count(*) as N, count(distinct AD_PERF_DK) as N_DK, SUM(AD_COST) as COST
    from {{ ref('FACT_AD_PERFORMANCE') }}
    group by 1
)
select
    COALESCE(s.AD_SOURCE_TYPE, f.AD_SOURCE_TYPE) as AD_SOURCE_TYPE,
    s.N as SRC_ROWS, f.N as FACT_ROWS, f.N_DK as FACT_DISTINCT_DK,
    s.COST as SRC_COST, f.COST as FACT_COST
from src s
full outer join fct f on f.AD_SOURCE_TYPE = s.AD_SOURCE_TYPE
where COALESCE(s.N, 0) <> COALESCE(f.N, 0)
   or COALESCE(f.N, 0) <> COALESCE(f.N_DK, 0)
   or COALESCE(s.COST, 0) <> COALESCE(f.COST, 0)
