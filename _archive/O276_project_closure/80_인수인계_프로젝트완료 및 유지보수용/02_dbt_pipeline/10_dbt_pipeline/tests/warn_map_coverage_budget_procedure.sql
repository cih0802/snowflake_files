-- =============================================================================
-- Purpose    : [2026-10-22 O258] 예산 편성 차수 원천 라벨 ↔ seed MAP_BUDGET_PROCEDURE 커버리지 경고
-- Target     : dbt singular test warn_map_coverage_budget_procedure (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref ERP_BUDGET, ref ERP_BUDGET_YEARLY, ref CRM_BIZ_TARGET, ref MAP_BUDGET_PROCEDURE
-- Issue      : O258
-- =============================================================================
-- 왜: 차수 판정을 모델 CASE 에서 seed 로 옮겼다(O258). 원천에 새 표기가 들어오면 FACT_BUDGET* 는 PRCD_SEQ 0 으로,
--   CRM_BIZ_TARGET 은 원문 그대로 흘러 FACT_TARGET_PROJECT 의 ANNUAL/SUPP 어디에도 들지 않을 수 있다(조용한 누락).
-- 반환 행 = 원천에 있는데 seed 에 없는 라벨 · 판정: WARN → seeds/MAP_BUDGET_PROCEDURE.csv 에 행을 더하고 dbt seed.
{{ config(severity = 'warn') }}

with src as (
    select 'ERP_BUDGET' as SRC, BUDGET_PROCEDURE as LBL from {{ ref('ERP_BUDGET') }}
    union
    select 'ERP_BUDGET_YEARLY', BUDGET_PROCEDURE from {{ ref('ERP_BUDGET_YEARLY') }}
    union
    select 'CRM_BIZ_TARGET', BDGT_PRCD_NM from {{ ref('CRM_BIZ_TARGET') }}
)
select s.SRC, s.LBL as UNMAPPED_LABEL
from src s
left join {{ ref('MAP_BUDGET_PROCEDURE') }} m on m.SRC_LABEL = s.LBL
where s.LBL is not null
  and m.SRC_LABEL is null
