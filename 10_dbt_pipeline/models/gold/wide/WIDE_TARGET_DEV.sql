-- WIDE_TARGET_DEV: 회원개발 목표 팩트(FTG_D) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.3)
-- Co-authored with CoCo
{{ config(
    materialized='view',
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '회원개발 목표 평탄화 (FTG_D × ORG[as-was]). 월 grain=MONTH_KEY.'",
      "ALTER VIEW {{ this }} ALTER COLUMN MONTH_KEY COMMENT '목표월 YYYYMM', COLUMN CAL_YEAR COMMENT 'FLOOR(MONTH_KEY/100) — 연도', COLUMN CAL_MONTH COMMENT 'MOD(MONTH_KEY,100) — 월', COLUMN DEV_TYPE COMMENT '개발구분 (#121 conform)', COLUMN GOAL_CNT COMMENT '회원개발목표(건) (CRM TM_CM_MBER_DVLP_GOAL)', COLUMN DW_SOURCE_SYSTEM COMMENT '원천 시스템 식별', COLUMN ORG_CORP COMMENT 'DIM_ORG.CORP — 법인 (as-was #114)', COLUMN ORG_DIVISION COMMENT 'DIM_ORG.DIVISION — 본부/지부 (as-was #115)', COLUMN ORG_DEPARTMENT COMMENT 'DIM_ORG.DEPARTMENT — 부서 (as-was #116)', COLUMN ORG_TEAM COMMENT 'DIM_ORG.TEAM — 팀 (as-was)'"
    ]
) }}

select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.DEV_TYPE, f.GOAL_CNT, f.DW_SOURCE_SYSTEM,
    o.CORP as ORG_CORP, o.DIVISION as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT, o.TEAM as ORG_TEAM
from {{ ref('FACT_TARGET_DEV') }} f
left join {{ ref('DIM_ORG') }} o on f.ORG_SK = o.ORG_SK
