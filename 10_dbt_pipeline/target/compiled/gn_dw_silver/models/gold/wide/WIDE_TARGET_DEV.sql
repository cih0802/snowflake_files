-- WIDE_TARGET_DEV: 회원개발 목표 팩트(FTG_D) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.3)
-- Co-authored with CoCo


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.DEV_TYPE, f.GOAL_CNT, f.DW_SOURCE_SYSTEM,
    o.CORP as ORG_CORP, o.DIVISION as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT, o.TEAM as ORG_TEAM
from GN_DW.GOLD.FACT_TARGET_DEV f
left join GN_DW.GOLD.DIM_ORG o on f.ORG_SK = o.ORG_SK