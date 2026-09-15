-- DIM_DATE: 날짜 차원 (순서9: GA4 의존 제거 → 고정 연속 캘린더 cal_start~cal_end + DATE_SK=0 Unknown)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key='DATE_SK',
    tags=['gold_ready']
) }}

with spine as (
    -- 고정 연속 캘린더. rowcount 는 cal_start~cal_end 의 실제 일수를 jinja 로 산출(매직상수 제거).
    --   순서9-B: 기존 하드코딩 16500 은 cal_end 확장 시 캘린더가 조용히 잘리는 잠복 결함 → 범위에서 자동 계산으로 대체.
    select DATEADD(day, SEQ4(), DATE '{{ var("cal_start") }}') as FULL_DATE
    from TABLE(GENERATOR(rowcount => {{ (modules.datetime.datetime.strptime(var("cal_end"), "%Y-%m-%d") - modules.datetime.datetime.strptime(var("cal_start"), "%Y-%m-%d")).days + 1 }}))
),

calendar as (
    select
        {{ date_sk('FULL_DATE') }}                    as DATE_SK,
        FULL_DATE                                     as FULL_DATE,
        YEAR(FULL_DATE)                               as YEAR,
        MONTH(FULL_DATE)                              as MONTH,
        {{ month_key('FULL_DATE') }}                  as MONTH_KEY,
        DAY(FULL_DATE)                                as DAY,
        DAYOFWEEK(FULL_DATE)                          as DAY_OF_WEEK,
        WEEKOFYEAR(FULL_DATE)                         as WEEK_OF_YEAR,
        QUARTER(FULL_DATE)                            as QUARTER,
        FALSE                                         as IS_HOLIDAY,   -- ⚠️ 휴일 원천 없음(추후 보정)
        {{ gold_meta('DW') }}
    from spine
    where FULL_DATE <= DATE '{{ var("cal_end") }}'
)

select * from calendar
union all
-- 순서9 Unknown 멤버: fact 의 미상·범위밖·NULL 날짜 라우팅 대상(DATE_SK=0).
-- 🔴 [2026-09-15] NULL → **센티넬 값**으로 교체. 종전 이 행은 FULL_DATE·YEAR·MONTH·DAY·
--   DAY_OF_WEEK·WEEK_OF_YEAR·QUARTER 에 NULL 을 넣었는데 06_DDL 은 그 7컬럼이 **전부 NOT NULL** 이라
--   build 가 `100072 NULL result in a non-nullable column` 으로 죽었다(권한 문제가 아니었다).
--   ⚠️ DDL 이 옳다 — 센티넬 규약은 문서 4곳에 확정돼 있다: `06_DDL.sql:75`(SK=0 '(미매핑)'),
--      `02_DB_BRONZE_SILVER.md:318`(「구설계 -1 UNKNOWN 표기 폐기」)·`:350`, 필드인벤토리 260행
--      DIM_DEVICE 실례가 SK=0 행에 `'(unknown)'` 문자열을 채운다. 즉 **Unknown 멤버는 NULL 이 아니라 값**이다.
--   값 선택 근거:
--     · 숫자 7컬럼 = **0**. 이 파일이 이미 MONTH_KEY 에 0 을 쓰던 관례를 나머지로 확장한 것이다.
--       0 은 어떤 실제 연/월/일/분기값도 아니라서 실캘린더 행과 절대 충돌하지 않는다.
--     · FULL_DATE = **1900-01-01**. DATE 타입에는 0 이 없어 숫자와 같은 방식을 쓸 수 없다.
--       cal_start(1991-01-01) **밖**이라 실캘린더 행과 겹치지 않고 식별 가능하다.
--   🔴 그래서 남는 부정합 하나를 명시해 둔다: 이 행은 FULL_DATE=1900-01-01 인데 YEAR=0 이다
--      (YEAR(FULL_DATE) 와 불일치). 의도된 것이다 — 숫자축은 「0=미상」 규약을, 날짜축은 타입 제약을
--      각각 따른 결과다. ⚠️ 따라서 이 행을 YEAR 로 집계하면 0 버킷에 모이고 FULL_DATE 로 집계하면
--      1900 버킷에 모인다. 두 축을 섞어 검증하지 말 것.
--   ⚠️ 센티넬 **날짜값 자체**는 설계문서에 규정이 없다(규약은 「NULL 금지」까지만 정한다) —
--      1900-01-01 은 이 커밋의 선택이다. 바꾸려면 여기 한 곳만 고치면 된다.
select 0, DATE '1900-01-01', 0, 0, 0, 0, 0, 0, 0, FALSE, {{ gold_meta('DW') }}
