-- WIDE_MEMBER_COHORT_SURVIVAL: 회원 획득 코호트 생존 집계 뷰(분류 축 × 획득 후 경과월) — LTV 기대 유지개월 산출용
-- Co-authored with CoCo
-- 🆕 [2026-10-15 O231 · 🟠 잠정 정의 — 현업 확인 전] 사용자 결정 = 기본값 먼저 구현 → 피드백 후 설정 수정.
--   방법 = Kaplan–Meier(월 이산). 입력 = FACT_MEMBER_COHORT.OBS_TENURE_MONTHS(T) · IS_STOPPED_OBS(중단 1 / 관측 중 0).
--   · AT_RISK(m)   = T ≥ m 인 회원수(그 경과월 시작 시점 위험 집합)
--   · STOP(m)      = T = m 이고 중단한 회원수 · CENSORED(m) = T = m 이고 관측 중(우절단)
--   · SURV_END(m)  = Π_{k≤m} (1 − STOP(k)/AT_RISK(k)) = P(T > m) · SURV_START(m) = P(T ≥ m) = SURV_END(m−1)
--   · RMST_CUM(m)  = Σ_{k≤m} SURV_START(k) ⇒ 상한 τ 의 기대 유지개월 = RMST_CUM(τ−1) = E[min(T, τ)]
--   🔴 표준 RMST 다(사용자 O231). O230 진단식 1+Σ_{t<τ}S(t) 는 τ+1 항이라 S(τ−1) 만큼 크다(전체 36 기준 약 +0.6개월).
--   🔴 축 = **획득 후 경과월**(달력월 아님). 위험 회원이 0 이 된 뒤의 경과월은 마지막 생존율을 이어 쓴다(KM 관례 · 관측 범위 밖).
--   🔴 설정 = dbt vars `ltv_caps`(상한 목록) · `ltv_learn_start`(획득 시작일 · null = 전체 이력) · `ltv_min_cell`(셀 최소 회원수).
--      상한을 바꾸면 EXP_TENURE_*M · SURV_*M 컬럼명이 함께 바뀐다 ⇒ `_wide_schema.yml` 과 SV_MEMBER_COHORT 도 같이 고친다.
--   🔴 회원 1행이 아니다 — 행 = 축값 × 경과월. 축(AXIS_TYPE)을 섞어 합산하지 않는다(같은 회원이 축마다 한 번씩 들어 있다).
{{ config(
    materialized='gn_view_commented'
) }}
{%- set caps = var('ltv_caps', [36, 60]) -%}
{%- set horizon = caps | max -%}
{%- set learn_start = var('ltv_learn_start', none) -%}
with base as (
    select
        OBS_TENURE_MONTHS                                   as T,
        IS_STOPPED_OBS                                      as E,
        COALESCE(ACQ_MBER_INFLOW_PATH_NM, '(미상)')          as INFLOW_PATH,
        COALESCE(ACQ_CMPGN_CTGR_NM, '(미상)')                as CMPGN_CTGR,
        COALESCE(ACQ_CMPGN_TYPE1_NM, '(미상)')               as CMPGN_TYPE1,
        COALESCE(ACQ_CMPGN_TYPE2_NM, '(미상)')               as CMPGN_TYPE2
    from {{ ref('FACT_MEMBER_COHORT') }}
    where OBS_TENURE_MONTHS is not null
    {%- if learn_start %}
      and ACQ_DATE_SK >= {{ learn_start | replace('-', '') }}
    {%- endif %}
),
ax as (
    select '전체' as AXIS_TYPE, '전체' as AXIS_VALUE, T, E from base
    union all select '개발인입경로', INFLOW_PATH, T, E from base
    union all select '캠페인카테고리', CMPGN_CTGR, T, E from base
    union all select '캠페인유형1', CMPGN_TYPE1, T, E from base
    union all select '캠페인유형2', CMPGN_TYPE2, T, E from base
),
cell as (
    select AXIS_TYPE, AXIS_VALUE, COUNT(*) as COHORT_MEMBERS, SUM(E) as STOPPED_MEMBERS_TOTAL
    from ax group by 1, 2
),
months as (
    select ROW_NUMBER() over (order by SEQ4()) - 1 as ELAPSED_MONTH
    from table(GENERATOR(ROWCOUNT => {{ horizon }}))
),
g as (
    select AXIS_TYPE, AXIS_VALUE, T, COUNT(*) as N_END, SUM(E) as D
    from ax where T < {{ horizon }} group by 1, 2, 3
),
j as (
    select c.AXIS_TYPE, c.AXIS_VALUE, c.COHORT_MEMBERS, c.STOPPED_MEMBERS_TOTAL, m.ELAPSED_MONTH,
           COALESCE(g.N_END, 0) as N_END, COALESCE(g.D, 0) as D
    from cell c
    cross join months m
    left join g on g.AXIS_TYPE = c.AXIS_TYPE and g.AXIS_VALUE = c.AXIS_VALUE and g.T = m.ELAPSED_MONTH
),
r as (
    select j.*,
           COHORT_MEMBERS - COALESCE(SUM(N_END) over (partition by AXIS_TYPE, AXIS_VALUE order by ELAPSED_MONTH
                                                      rows between unbounded preceding and 1 preceding), 0) as AT_RISK
    from j
),
s as (
    select r.*,
           EXP(SUM(LN(GREATEST(IFF(AT_RISK > 0, 1 - D / AT_RISK, 1), 1e-12)))
               over (partition by AXIS_TYPE, AXIS_VALUE order by ELAPSED_MONTH
                     rows between unbounded preceding and current row)) as SURV_END
    from r
),
s2 as (
    select s.*,
           COALESCE(LAG(SURV_END) over (partition by AXIS_TYPE, AXIS_VALUE order by ELAPSED_MONTH), 1) as SURV_START
    from s
),
s3 as (
    select s2.*,
           SUM(SURV_START) over (partition by AXIS_TYPE, AXIS_VALUE order by ELAPSED_MONTH
                                 rows between unbounded preceding and current row) as RMST_CUM
    from s2
)
select
    AXIS_TYPE,
    AXIS_VALUE,
    ELAPSED_MONTH,
    AT_RISK                                         as AT_RISK_MEMBERS,
    D                                               as STOP_MEMBERS,
    N_END - D                                       as CENSORED_MEMBERS,
    SURV_START,
    SURV_END,
    RMST_CUM,
    COHORT_MEMBERS,
    STOPPED_MEMBERS_TOTAL,
    COHORT_MEMBERS >= {{ var('ltv_min_cell', 500) }} as IS_CELL_RELIABLE,
    {%- for c in caps %}
    MAX(IFF(ELAPSED_MONTH = {{ c - 1 }}, RMST_CUM, NULL)) over (partition by AXIS_TYPE, AXIS_VALUE) as EXP_TENURE_{{ c }}M,
    MAX(IFF(ELAPSED_MONTH = {{ c - 1 }}, SURV_END, NULL)) over (partition by AXIS_TYPE, AXIS_VALUE) as SURV_{{ c }}M,
    {%- endfor %}
    MAX(IFF(ELAPSED_MONTH = 11, SURV_END, NULL)) over (partition by AXIS_TYPE, AXIS_VALUE) as SURV_12M,
    '{{ learn_start if learn_start else "전체 이력" }}' as LEARN_START
from s3
