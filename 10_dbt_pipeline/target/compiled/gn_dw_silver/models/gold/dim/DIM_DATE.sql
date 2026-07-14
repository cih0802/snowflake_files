-- DIM_DATE: 날짜 차원 (GA4_EVENT 일자 범위로 캘린더 생성, 1일 grain)
-- Co-authored with CoCo


with bounds as (
    select MIN(EVENT_DT) as d0, MAX(EVENT_DT) as d1
    from GN_DW.SILVER.GA4_EVENT
),

spine as (
    -- 20년(7305일) 스파인 후 데이터 상한으로 필터. GENERATOR rowcount 는 상수 필수.
    select DATEADD(day, SEQ4(), b.d0) as FULL_DATE, b.d1 as D1
    from TABLE(GENERATOR(rowcount => 7305)) g
    cross join bounds b
)

select
    TRY_TO_NUMBER(TO_CHAR(FULL_DATE, 'YYYYMMDD'))                    as DATE_SK,
    FULL_DATE                                     as FULL_DATE,
    YEAR(FULL_DATE)                               as YEAR,
    MONTH(FULL_DATE)                              as MONTH,
    TRY_TO_NUMBER(TO_CHAR(FULL_DATE, 'YYYYMM'))                  as MONTH_KEY,
    DAY(FULL_DATE)                                as DAY,
    DAYNAME(FULL_DATE)                            as DAY_OF_WEEK,
    WEEKOFYEAR(FULL_DATE)                         as WEEK_OF_YEAR,
    QUARTER(FULL_DATE)                            as QUARTER,
    FALSE                                         as IS_HOLIDAY,   -- ⚠️ 휴일 원천 없음(추후 보정)
    'DW'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '24b70347-040a-40c6-b075-ccde404e290d'                    AS DW_BATCH_ID
from spine
where FULL_DATE <= D1