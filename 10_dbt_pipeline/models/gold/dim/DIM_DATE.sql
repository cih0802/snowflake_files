-- DIM_DATE: 날짜 차원 (순서9: GA4 의존 제거 → 고정 연속 캘린더 cal_start~cal_end + DATE_SK=0 Unknown)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='DATE_SK',
    tags=['gold_ready']
) }}

with spine as (
    -- 고정 연속 캘린더. GENERATOR rowcount 는 상수 필수(범위 여유분 생성 후 cal_end 로 필터).
    select DATEADD(day, SEQ4(), DATE '{{ var("cal_start") }}') as FULL_DATE
    from TABLE(GENERATOR(rowcount => 16500))
),

calendar as (
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
    where FULL_DATE <= DATE '{{ var("cal_end") }}'
)

select * from calendar
union all
-- 순서9 Unknown 멤버: fact 의 미상·범위밖·NULL 날짜 라우팅 대상(DATE_SK=0). MONTH_KEY NOT-NULL 테스트 대비 0.
select 0, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, FALSE, {{ gold_meta('DW') }}
