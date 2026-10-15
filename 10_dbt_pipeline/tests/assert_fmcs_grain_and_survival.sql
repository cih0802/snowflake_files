-- assert_fmcs_grain_and_survival: FACT_MEMBER_COHORT_SURVIVAL grain 유일성 + 생존 곡선 불변식 (O232 신설)
-- Co-authored with CoCo
-- 반환 행 = 위반(0행이어야 PASS). dbt_utils 미설치라 singular 테스트로 둔다.
--   ㉠ grain(AXIS_TYPE × AXIS_VALUE × ELAPSED_MONTH) 중복
--   ㉡ 생존율 범위 [0, 1] 밖 · SURV_END > SURV_START(곡선은 증가하지 않는다)
--   ㉢ 셀마다 상한 표지(LTV_CAP_MONTHS) 행 수 ≠ dbt var ltv_caps 개수 — 상한을 바꿨는데 행 표지가 따라오지 않은 경우
--   ㉣ 축 「전체」 COHORT_MEMBERS ≠ FACT_MEMBER_COHORT 생존분석 대상 회원수(입력 누락·중복)
{%- set n_caps = var('ltv_caps', [36, 60]) | length %}
select 'GRAIN_DUP:' || AXIS_TYPE || '|' || AXIS_VALUE || '|' || ELAPSED_MONTH as CHECK_NM, COUNT(*) as V
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
group by AXIS_TYPE, AXIS_VALUE, ELAPSED_MONTH
having COUNT(*) > 1

union all

select 'SURV_RANGE:' || AXIS_TYPE || '|' || AXIS_VALUE || '|' || ELAPSED_MONTH, 1
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
where SURV_END < 0 or SURV_END > 1 or SURV_START < 0 or SURV_START > 1 or SURV_END > SURV_START

union all

select 'CAP_ROWS:' || AXIS_TYPE || '|' || AXIS_VALUE, COUNT(LTV_CAP_MONTHS)
from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }}
group by AXIS_TYPE, AXIS_VALUE
having COUNT(LTV_CAP_MONTHS) <> {{ n_caps }}

union all

select 'TOTAL_MEMBERS_MISMATCH', s.N - c.N
from (select MAX(COHORT_MEMBERS) as N from {{ ref('FACT_MEMBER_COHORT_SURVIVAL') }} where AXIS_TYPE = '전체') s
cross join (select COUNT(OBS_TENURE_MONTHS) as N from {{ ref('FACT_MEMBER_COHORT') }}) c
where s.N <> c.N
