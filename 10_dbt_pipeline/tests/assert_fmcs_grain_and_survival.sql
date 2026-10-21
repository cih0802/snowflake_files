-- assert_fmcs_grain_and_survival: FACT_MEMBER_COHORT_SURVIVAL grain 유일성 + 생존 곡선 불변식 (O232 신설)
-- Co-authored with CoCo
-- 반환 행 = 위반(0행이어야 PASS). dbt_utils 미설치라 singular 테스트로 둔다.
--   ㉠ grain(AXIS_TYPE × AXIS_VALUE × ELAPSED_MONTH) 중복
--   ㉡ 생존율 범위 [0, 1] 밖 · SURV_END > SURV_START(곡선은 증가하지 않는다)
--   ㉢ 셀마다 상한 표지(LTV_CAP_AVG_ACTIVE_MONTHS ≠ 9999) 행 수 ≠ 1 — 🆕 [O249] 상한은 계산형 1값(구 ltv_caps 개수)
--   ㉣ 축 「전체」 COHORT_MEMBERS ≠ FACT_MEMBER_COHORT 생존분석 대상 회원수(입력 누락·중복)
--   🆕 [O249] ㉥ 상한값 ≠ CEIL(관측 중 회원 평균 유지개월) — 계산식과 표지가 어긋난 경우
{%- set n_caps = 1 %}
select 'GRAIN_DUP:' || AXIS_TYPE || '|' || AXIS_VALUE || '|' || ELAPSED_MONTH as CHECK_NM, COUNT(*) as V
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
group by AXIS_TYPE, AXIS_VALUE, ELAPSED_MONTH
having COUNT(*) > 1

union all

select 'SURV_RANGE:' || AXIS_TYPE || '|' || AXIS_VALUE || '|' || ELAPSED_MONTH, 1
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
where SURV_END < 0 or SURV_END > 1 or SURV_START < 0 or SURV_START > 1 or SURV_END > SURV_START

union all

select 'CAP_ROWS:' || AXIS_TYPE || '|' || AXIS_VALUE, COUNT_IF(LTV_CAP_AVG_ACTIVE_MONTHS <> 9999)
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
group by AXIS_TYPE, AXIS_VALUE
having COUNT_IF(LTV_CAP_AVG_ACTIVE_MONTHS <> 9999) <> {{ n_caps }}

union all

-- 🆕 [O233] ㉤ 무기한 표지(9999) = 셀의 최대 관측월(관측이 끝난 마지막 경과월) 행에 정확히 1개.
--   예외 = 그 경과월이 상한−1 과 겹치면 상한 표지가 우선한다(모델 주석 · RMST 동일).
--   horizon(ltv_horizon_max)이 최대 관측월보다 짧으면 이 검사가 잡는다.
select 'UNLIMITED_ROW:' || t.AXIS_TYPE || '|' || t.AXIS_VALUE, COUNT_IF(t.LTV_CAP_AVG_ACTIVE_MONTHS = 9999)
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }} t
join (
    select AXIS_TYPE, AXIS_VALUE, MAX(IFF(STOP_MEMBERS + CENSORED_MEMBERS > 0, ELAPSED_MONTH, NULL)) as MAX_T
    from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
    group by 1, 2
) m on m.AXIS_TYPE = t.AXIS_TYPE and m.AXIS_VALUE = t.AXIS_VALUE
cross join (
    select MAX(IFF(LTV_CAP_AVG_ACTIVE_MONTHS <> 9999, LTV_CAP_AVG_ACTIVE_MONTHS, NULL)) as CAP_M
    from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
) c
group by t.AXIS_TYPE, t.AXIS_VALUE, m.MAX_T, c.CAP_M
having COUNT_IF(t.LTV_CAP_AVG_ACTIVE_MONTHS = 9999) <> IFF(m.MAX_T + 1 = c.CAP_M, 0, 1)

union all

select 'CAP_FORMULA_MISMATCH', s.CAP_M - f.CAP_M
from (
    select MAX(IFF(LTV_CAP_AVG_ACTIVE_MONTHS <> 9999, LTV_CAP_AVG_ACTIVE_MONTHS, NULL)) as CAP_M
    from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
) s
cross join (
    select CEIL(AVG(IFF(IS_STOPPED_OBS_LAST = 0, OBS_TENURE_MONTHS_LAST, NULL))) as CAP_M
    from {{ ref('FACT_MEMBER_COHORT') }}
    where OBS_TENURE_MONTHS is not null
    {%- if var('ltv_learn_start', none) %}
      and ACQ_DATE_SK >= {{ var('ltv_learn_start') | replace('-', '') }}
    {%- endif %}
) f
where s.CAP_M <> f.CAP_M

union all

select 'TOTAL_MEMBERS_MISMATCH', s.N - c.N
from (select MAX(COHORT_MEMBERS) as N from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }} where AXIS_TYPE = '전체') s
cross join (select COUNT(OBS_TENURE_MONTHS) as N from {{ ref('FACT_MEMBER_COHORT') }}) c
where s.N <> c.N
