-- DIM_DATE: 날짜 차원 (GA4_EVENT 일자 범위로 캘린더 생성, 1일 grain)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='DATE_SK',
    tags=['gold_ready']
) }}

with bounds as (
    select MIN(EVENT_DT) as d0, MAX(EVENT_DT) as d1
    from {{ ref('GA4_EVENT') }}
),

spine as (
    -- 20년(7305일) 스파인 후 데이터 상한으로 필터. GENERATOR rowcount 는 상수 필수.
    select DATEADD(day, SEQ4(), b.d0) as FULL_DATE, b.d1 as D1
    from TABLE(GENERATOR(rowcount => 7305)) g
    cross join bounds b
)

select
    {{ date_sk('FULL_DATE') }}                    as DATE_SK,
    FULL_DATE                                     as FULL_DATE,
    YEAR(FULL_DATE)                               as YEAR,
    MONTH(FULL_DATE)                              as MONTH,
    {{ month_key('FULL_DATE') }}                  as MONTH_KEY,
    DAY(FULL_DATE)                                as DAY,
    DAYNAME(FULL_DATE)                            as DAY_OF_WEEK,
    WEEKOFYEAR(FULL_DATE)                         as WEEK_OF_YEAR,
    QUARTER(FULL_DATE)                            as QUARTER,
    FALSE                                         as IS_HOLIDAY,   -- ⚠️ 휴일 원천 없음(추후 보정)
    {{ gold_meta('DW') }}
from spine
where FULL_DATE <= D1
