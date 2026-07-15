-- DIM_DATE: 날짜 차원 (순서9: GA4 의존 제거 → 고정 연속 캘린더 cal_start~cal_end + DATE_SK=0 Unknown)
-- Co-authored with CoCo


with spine as (
    -- 고정 연속 캘린더. rowcount 는 cal_start~cal_end 의 실제 일수를 jinja 로 산출(매직상수 제거).
    --   순서9-B: 기존 하드코딩 16500 은 cal_end 확장 시 캘린더가 조용히 잘리는 잠복 결함 → 범위에서 자동 계산으로 대체.
    select DATEADD(day, SEQ4(), DATE '1991-01-01') as FULL_DATE
    from TABLE(GENERATOR(rowcount => 16436))
),

calendar as (
    select
        CASE WHEN FULL_DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(FULL_DATE, 'YYYYMMDD')) END                    as DATE_SK,
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
    '79c7f449-64e1-46aa-9c0c-b206859bd7a3'                    AS DW_BATCH_ID
    from spine
    where FULL_DATE <= DATE '2035-12-31'
)

select * from calendar
union all
-- 순서9 Unknown 멤버: fact 의 미상·범위밖·NULL 날짜 라우팅 대상(DATE_SK=0). MONTH_KEY NOT-NULL 테스트 대비 0.
select 0, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, FALSE, 'DW'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '79c7f449-64e1-46aa-9c0c-b206859bd7a3'                    AS DW_BATCH_ID