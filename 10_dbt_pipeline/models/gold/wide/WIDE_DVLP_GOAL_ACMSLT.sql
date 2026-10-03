-- WIDE_DVLP_GOAL_ACMSLT: 연간 개발 목표·실적 부서 집계 → 월 행 언피벗 소비뷰 (O200-A 신설)
-- Co-authored with CoCo
-- 원천 = SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA(외부 적재 · 부서 자체 수식 · ML 산출물 아님).
-- 변환 = ① M01~M12 열 → 월 행(UNPIVOT INCLUDE NULLS) ② DATA_TYPE_NM(목표/실적) → GOAL_CNT·ACMSLT_CNT 열 분리.
-- grain = MONTH_KEY × DEPT_DIV_NM × NEW_EXST_DIV_NM × SPNSR_BSNS_GRP_NM (tests/assert_dept_aggr_grain_unique.sql).
-- COMMENT 정본 = `_wide_dept_aggr_schema.yml`(columns[] 는 SELECT 와 개수·순서 일치).
{{ config(
    materialized='gn_view_commented'
) }}

with unpvt as (
    select
        YEAR, DATA_TYPE_NM, DEPT_DIV_NM, NEW_EXST_DIV_NM, SPNSR_BSNS_GRP_NM,
        MM, CNT
    from {{ source('silver_external', 'ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA') }}
    unpivot include nulls (CNT for MM in (M01, M02, M03, M04, M05, M06, M07, M08, M09, M10, M11, M12))
)

select
    TO_NUMBER(YEAR) * 100 + TO_NUMBER(SUBSTR(MM, 2)) as MONTH_KEY,
    TO_NUMBER(YEAR)                                  as CAL_YEAR,
    TO_NUMBER(SUBSTR(MM, 2))                         as CAL_MONTH,
    DEPT_DIV_NM,
    NEW_EXST_DIV_NM,
    SPNSR_BSNS_GRP_NM,
    MAX(IFF(DATA_TYPE_NM = '목표', CNT, NULL))       as GOAL_CNT,
    MAX(IFF(DATA_TYPE_NM = '실적', CNT, NULL))       as ACMSLT_CNT
from unpvt
group by 1, 2, 3, 4, 5, 6
