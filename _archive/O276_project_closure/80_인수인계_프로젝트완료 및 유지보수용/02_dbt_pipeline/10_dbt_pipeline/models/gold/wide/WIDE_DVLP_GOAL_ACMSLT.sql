-- =============================================================================
-- Purpose    : 연간 개발 목표·실적 부서 집계 → 월 행 언피벗 소비뷰 (O200-A 신설)
-- Target     : GOLD.WIDE_DVLP_GOAL_ACMSLT (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source silver_external.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA
-- Issue      : O200-A
-- =============================================================================
-- WIDE_DVLP_GOAL_ACMSLT: 연간 개발 목표·실적 부서 집계 → 월 행 언피벗 소비뷰 (O200-A 신설)
-- 원천 = SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = ① M01~M12 열 → 월 행(UNPIVOT INCLUDE NULLS) ② DATA_TYPE_NM(목표/실적) → GOAL_CNT·ACMSLT_CNT 열 분리.
-- grain = MONTH_KEY × DEPT_DIV_NM × NEW_EXST_DIV_NM × SPNSR_BSNS_GRP_NM (tests/assert_dept_aggr_grain_unique.sql).
-- COMMENT 정본 = `_wide_dept_aggr_schema.yml`(columns[] 는 SELECT 와 개수·순서 일치).
{{ config(
    materialized='gn_view_commented'
) }}

with unpvt as (
    select
        u.YEAR, u.DATA_TYPE_NM, u.DEPT_DIV_NM, u.NEW_EXST_DIV_NM, u.SPNSR_BSNS_GRP_NM,
        u.MM, u.CNT,
        --  [2026-10-22 O258] 수기 라벨(목표/실적) → seed MAP_EXT_DATA_TYPE 표준값(라벨 하드코딩 제거 · 종전과 값 동일).
        --   WARN: 매핑에 없는 라벨은 NULL ⇒ GOAL·ACMSLT 어느 쪽에도 들지 않는다(추정 금지 · tests/warn_map_coverage_ext_data_type).
        m.DATA_TYPE_STD
    from {{ source('silver_external', 'ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA') }}
    unpivot include nulls (CNT for MM in (M01, M02, M03, M04, M05, M06, M07, M08, M09, M10, M11, M12)) u
    left join {{ ref('MAP_EXT_DATA_TYPE') }} m
      on m.SOURCE_TABLE = 'ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA'
     and m.SRC_LABEL = TRIM(u.DATA_TYPE_NM)
)

select
    TO_NUMBER(YEAR) * 100 + TO_NUMBER(SUBSTR(MM, 2)) as MONTH_KEY,
    TO_NUMBER(YEAR)                                  as CAL_YEAR,
    TO_NUMBER(SUBSTR(MM, 2))                         as CAL_MONTH,
    DEPT_DIV_NM,
    NEW_EXST_DIV_NM,
    SPNSR_BSNS_GRP_NM,
    --  표준값(seed 가 정하는 어휘) 기준 열 분리 — 원천 라벨이 바뀌어도 이 줄은 바꾸지 않는다.
    MAX(IFF(DATA_TYPE_STD = '목표', CNT, NULL))      as GOAL_CNT,
    MAX(IFF(DATA_TYPE_STD = '실적', CNT, NULL))      as ACMSLT_CNT
from unpvt
group by 1, 2, 3, 4, 5, 6
