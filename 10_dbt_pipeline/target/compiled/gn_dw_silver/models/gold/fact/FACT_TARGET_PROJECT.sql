-- FACT_TARGET_PROJECT: 프로젝트/사업목표 팩트 (CRM_BIZ_TARGET, 월×조직×후원사업×캠페인)
-- Co-authored with CoCo


with t as (
    select * from GN_DW.SILVER.CRM_BIZ_TARGET
    where COALESCE(TARGET_CNT, 0) > 0
)

select
    COALESCE(CASE WHEN TRY_TO_NUMBER(t.MONTH_KEY) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(t.MONTH_KEY), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(t.MONTH_KEY) END, 0)  as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    COALESCE(s.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,
    c.CAMPAIGN_SK                                  as CAMPAIGN_SK,
    SUM(CASE WHEN t.TARGET_TYPE = '당초'   THEN t.TARGET_CNT END)  as ANNUAL_GOAL_CNT,
    SUM(CASE WHEN t.TARGET_TYPE LIKE '추경%' THEN t.TARGET_CNT END) as SUPP_GOAL_CNT,
    CAST(NULL AS NUMBER(18,4))                     as ANNUAL_CUM_GOAL_CNT,
    CAST(NULL AS NUMBER(18,4))                     as SUPP_CUM_GOAL_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '025f9ac5-d9be-4588-8381-cd1bfa260b2e'                    AS DW_BATCH_ID
from t
left join GN_DW.GOLD.DIM_ORG o
    on o.DEPARTMENT = t.ORG_NM
left join GN_DW.GOLD.DIM_SPONSORSHIP s
    on s.SPONSORSHIP_NAME = t.SPONSOR_BIZ_NM
left join GN_DW.GOLD.DIM_CAMPAIGN c
    on c.CAMPAIGN_NAME = t.CAMPAIGN_NM
group by 1, 2, 3, 4