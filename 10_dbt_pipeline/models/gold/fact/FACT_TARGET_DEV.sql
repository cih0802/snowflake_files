-- FACT_TARGET_DEV: 회원개발 목표 팩트 (CRM_DEV_TARGET, 월×조직×개발구분)
-- Co-authored with CoCo
-- ORG_SK 는 DIM_ORG.ORG_DK(=ABS(HASH(DEPT_ID)))로 해소. Bronze 입고 후 실행.
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
{{ config(
    tags=['gold_pending']
) }}

with t as (
    select * from {{ ref('CRM_DEV_TARGET') }}
)

select
    TRY_TO_NUMBER(t.STDR_MT)                      as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    t.MBER_DVLP_DIV_CD                            as DEV_TYPE,
    SUM(t.GOAL_CNT)                               as GOAL_CNT,
    {{ gold_meta('CRM') }}
from t
left join {{ ref('DIM_ORG') }} o
    on o.ORG_DK = ABS(HASH(t.DEPT_ID))
group by TRY_TO_NUMBER(t.STDR_MT), COALESCE(o.ORG_SK, 0), t.MBER_DVLP_DIV_CD
