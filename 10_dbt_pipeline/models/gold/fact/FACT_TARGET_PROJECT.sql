-- FACT_TARGET_PROJECT: 프로젝트/사업목표 팩트 (CRM_BIZ_TARGET, 월×조직×후원사업×캠페인)
-- Co-authored with CoCo
{{ config(
    tags=['gold_pending']
) }}

with t as (
    select * from {{ ref('CRM_BIZ_TARGET') }}
    where COALESCE(TARGET_CNT, 0) > 0
)

select
    COALESCE({{ month_key_clamp('TRY_TO_NUMBER(t.MONTH_KEY)') }}, 0)  as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    COALESCE(s.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,
    c.CAMPAIGN_SK                                  as CAMPAIGN_SK,
    SUM(CASE WHEN t.TARGET_TYPE = '당초'   THEN t.TARGET_CNT END)  as ANNUAL_GOAL_CNT,
    SUM(CASE WHEN t.TARGET_TYPE LIKE '추경%' THEN t.TARGET_CNT END) as SUPP_GOAL_CNT,
    CAST(NULL AS NUMBER(18,4))                     as ANNUAL_CUM_GOAL_CNT,
    CAST(NULL AS NUMBER(18,4))                     as SUPP_CUM_GOAL_CNT,
    {{ gold_meta('CRM') }}
from t
left join {{ ref('DIM_ORG') }} o
    on o.DEPARTMENT = t.ORG_NM
left join {{ ref('DIM_SPONSORSHIP') }} s
    on s.SPONSORSHIP_NAME = t.SPONSOR_BIZ_NM
left join {{ ref('DIM_CAMPAIGN') }} c
    on c.CAMPAIGN_NAME = t.CAMPAIGN_NM
group by 1, 2, 3, 4
