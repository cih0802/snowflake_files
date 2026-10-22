-- =============================================================================
-- Purpose    : [2026-10-22 O258] 외부 적재 부서 집계 DATA_TYPE_NM ↔ seed MAP_EXT_DATA_TYPE 커버리지 경고
-- Target     : dbt singular test warn_map_coverage_ext_data_type (반환 0행 = PASS)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source silver_external.ANNUAL_MBRFEE_PRDT_ACTL_DATA · ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA, ref MAP_EXT_DATA_TYPE
-- Issue      : O258
-- =============================================================================
-- 왜: 수기 라벨이 바뀌면(실사례 = 연초예측 → 연도초예측 · O257) 표준값이 NULL 이 되어
--   WIDE_MBRFEE_PRDT_ACTL 은 DATA_TYPE_STD NULL · WIDE_DVLP_GOAL_ACMSLT 는 GOAL/ACMSLT 양쪽 누락이 된다.
-- 반환 행 = 원천 테이블별로 seed 에 없는 라벨 · 판정: WARN → seeds/MAP_EXT_DATA_TYPE.csv 에 행을 더하고 dbt seed.
{{ config(severity = 'warn') }}

with src as (
    select distinct 'ANNUAL_MBRFEE_PRDT_ACTL_DATA' as SOURCE_TABLE, TRIM(DATA_TYPE_NM) as LBL
    from {{ source('silver_external', 'ANNUAL_MBRFEE_PRDT_ACTL_DATA') }}
    union
    select distinct 'ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA', TRIM(DATA_TYPE_NM)
    from {{ source('silver_external', 'ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA') }}
)
select s.SOURCE_TABLE, s.LBL as UNMAPPED_LABEL
from src s
left join {{ ref('MAP_EXT_DATA_TYPE') }} m
  on m.SOURCE_TABLE = s.SOURCE_TABLE and m.SRC_LABEL = s.LBL
where s.LBL is not null
  and m.SRC_LABEL is null
