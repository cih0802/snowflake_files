-- FACT_MEMBER_DEV_ACHIEVEMENT: 회원개발 목표 대비 실적 (월 conform)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook='TRUNCATE TABLE IF EXISTS {{ this }}',
    tags=['gold_ready']
) }}

-- 목표: 이미 MONTH_KEY × ORG_SK × DEV_TYPE grain
with goal as (
    select MONTH_KEY, ORG_SK, DEV_TYPE, SUM(GOAL_CNT) as GOAL_CNT
    from {{ ref('FACT_TARGET_MEMBER_DEV') }}
    group by MONTH_KEY, ORG_SK, DEV_TYPE
),

-- 실적: 일 grain 을 월로 롤업. 개발(DEV) 사건만 대상
actual as (
    select
        {{ month_key("f.JOIN_DATE") }}  as MONTH_KEY,
        f.ORG_SK                        as ORG_SK,
        f.DVLP_DIV_CD                   as DEV_TYPE,
        SUM(f.DEV_CNT)                  as ACTUAL_CNT
    from {{ ref('FACT_MEMBER_LIFECYCLE') }} f
    where f.EVENT_TYPE = 'DEV'
      and f.JOIN_DATE is not null
      and f.DVLP_DIV_CD in ('1', '2', '4')
    group by 1, 2, 3
),

joined as (
    select
        COALESCE(g.MONTH_KEY, a.MONTH_KEY) as MONTH_KEY,
        COALESCE(g.ORG_SK,    a.ORG_SK)    as ORG_SK,
        COALESCE(g.DEV_TYPE,  a.DEV_TYPE)  as DEV_TYPE,
        COALESCE(g.GOAL_CNT,   0)          as GOAL_CNT,
        COALESCE(a.ACTUAL_CNT, 0)          as ACTUAL_CNT,
        g.MONTH_KEY is not null            as HAS_GOAL_ROW,
        COALESCE(g.GOAL_CNT, 0) > 0        as HAS_POSITIVE_GOAL,
        a.MONTH_KEY is not null            as HAS_ACTUAL
    from goal g
    full outer join actual a
        on  g.MONTH_KEY = a.MONTH_KEY
        and g.ORG_SK    = a.ORG_SK
        and g.DEV_TYPE  = a.DEV_TYPE
),

cumulated as (
    select
        j.*,
        FLOOR(j.MONTH_KEY / 100) as CAL_YEAR,
        MOD(j.MONTH_KEY, 100)    as CAL_MONTH,
        SUM(j.GOAL_CNT)   over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE
                                order by j.MONTH_KEY
                                rows between unbounded preceding and current row) as GOAL_CNT_YTD,
        SUM(j.ACTUAL_CNT) over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE
                                order by j.MONTH_KEY
                                rows between unbounded preceding and current row) as ACTUAL_CNT_YTD,
        SUM(j.GOAL_CNT)   over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE) as GOAL_CNT_YEAR,
        SUM(j.ACTUAL_CNT) over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE) as ACTUAL_CNT_YEAR
    from joined j
)

select
    c.MONTH_KEY, c.CAL_YEAR, c.CAL_MONTH,
    c.ORG_SK,
    o.DEPARTMENT as ORG_DEPARTMENT,
    o.DIVISION   as ORG_DIVISION,
    o.TEAM       as ORG_TEAM,
    o.CORP       as ORG_CORP,
    c.DEV_TYPE,
    cd.DTL_CD_NM as DEV_TYPE_NAME,
    c.GOAL_CNT, c.ACTUAL_CNT,
    c.GOAL_CNT_YTD, c.ACTUAL_CNT_YTD,
    c.GOAL_CNT_YEAR, c.ACTUAL_CNT_YEAR,
    c.HAS_GOAL_ROW, c.HAS_POSITIVE_GOAL, c.HAS_ACTUAL,
    {{ gold_meta('CRM') }}
from cumulated c
left join {{ ref('DIM_ORG') }} o on c.ORG_SK = o.ORG_SK
left join (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'MM015'
) cd on c.DEV_TYPE = cd.DTL_CD_ID
