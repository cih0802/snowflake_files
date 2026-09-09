-- FACT_TARGET_MEMBER_DEV: 회원개발 목표 팩트 (CRM_DEV_TARGET, 월×조직×개발구분)
-- Co-authored with CoCo
{{ config(
    tags=['gold_pending']
) }}

with t as (
    select * from {{ ref('CRM_DEV_TARGET') }}
    where COALESCE(GOAL_CNT, 0) > 0
)

select
    COALESCE({{ month_key_clamp("TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0'))") }}, 0) as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    t.MBER_DVLP_DIV_CD                            as DEV_TYPE,
    SUM(t.GOAL_CNT)                               as GOAL_CNT,
    {{ gold_meta('CRM') }}
from t
left join {{ ref('DIM_ORG') }} o
    on o.ORG_DK = ABS(HASH(t.DEPT_ID))
group by
    COALESCE({{ month_key_clamp("TRY_TO_NUMBER(t.STDYY || LPAD(t.STDR_MT, 2, '0'))") }}, 0),
    COALESCE(o.ORG_SK, 0),
    t.MBER_DVLP_DIV_CD
