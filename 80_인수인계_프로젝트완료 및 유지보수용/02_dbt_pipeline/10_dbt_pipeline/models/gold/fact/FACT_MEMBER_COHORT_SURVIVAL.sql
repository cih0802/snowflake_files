-- FACT_MEMBER_COHORT_SURVIVAL: 획득 코호트 생존 곡선 팩트(분류 축 × 획득 후 경과월) — LTV 기대 유지개월 산출용
-- Co-authored with CoCo
-- 🆕 [2026-10-15 O232 · O234 확정(O234 현업 회신: 상한 80 + 무기한 · 전체 이력 · 재후원 포함 · 셀 최소 1)] O231 dbt 뷰 `WIDE_MEMBER_COHORT_SURVIVAL` → **GOLD 테이블**(사용자 결정).
--   구조 정본 = `03_top-down_gold/06_DDL.sql` FACT_MEMBER_COHORT_SURVIVAL · 모든 컬럼을 DDL 타입으로 CAST 한다
--   (dbt 롤은 구조 권한이 없다 · 타입이 넓으면 gn_no_structural_alter 가 SKIP 로그를 남긴다).
--   🔴 상한은 **컬럼이 아니라 행 표지** `LTV_CAP_AVG_ACTIVE_MONTHS`(🆕 O249 · 구 LTV_CAP_MONTHS) 다(O231 뷰는 EXP_TENURE_36M·60M 컬럼이라 상한을 바꾸면
--      yml·SV 컬럼명이 함께 바뀌었다) ⇒ 🆕 [O249] 상한은 데이터에서 계산된다(아래 cap CTE).
--   방법 = Kaplan–Meier(월 이산). 입력 = FACT_MEMBER_COHORT.OBS_TENURE_MONTHS(T) · IS_STOPPED_OBS(중단 1 / 관측 중 0).
--   · AT_RISK(m)  = T ≥ m 회원수 · STOP(m) = T = m 이고 중단 · CENSORED(m) = T = m 이고 관측 중
--   · SURV_END(m) = Π_{k≤m}(1 − STOP/AT_RISK) = P(T > m) · SURV_START(m) = P(T ≥ m)
--   · RMST_CUM(m) = Σ_{k≤m} SURV_START(k) ⇒ 상한 τ 의 기대 유지개월 = LTV_CAP_AVG_ACTIVE_MONTHS = τ 행의 RMST_CUM = E[min(T, τ)] (표준 · O231 사용자 결정)
--   🔴 축 = 획득 후 경과월(달력월 아님). 위험 회원이 0 이 된 뒤는 마지막 생존율을 이어 쓴다(KM 관례 · 관측 범위 밖).
--   🔴 행 = 축값 × 경과월 · 축(AXIS_TYPE)을 섞어 합산하지 않는다(같은 회원이 축마다 반복된다).
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    tags=['gold_ready']
) }}
{#- 🆕 [O249] 상한 = 고정 80 → **계산형** CAP = CEIL(AVG(관측 중 회원의 최종중단 기준 유지개월))(전체 모집단 1값 · 모든 셀 공통).
    근거 = 80 은 O234 현업 회신 상수였고 계산 로직이 없었다 · 후보 실측(SR61467 2026-10-20 · 1,622,973명):
    관측 중 평균 79.1 → CEIL 80(현행 재현) · KM 중앙값 72 · 전체 평균 58.7 · p75 85 ⇒ 관측 중 평균 채택.
    컬럼 = LTV_CAP_MONTHS → LTV_CAP_AVG_ACTIVE_MONTHS(계산식 기반 명칭). 🔴 데이터가 쌓이면 값이 움직인다(81 등). -#}
{#- 🆕 [O233] 무기한 = 셀별 최대 관측월 행에 LTV_CAP_AVG_ACTIVE_MONTHS = 9999 표지(현업 회신 「무기한」).
    경과월 범위 = max(최대 상한, 관측 최대월 + 1) — GENERATOR 행수는 상수여야 하므로 ltv_horizon_max 로 덮는다
    (실측 최대 관측월 426 · 2026-10-15 jw08094). 셀의 최대 관측월이 상한−1 과 같으면 상한 표지가 우선한다
    (두 값의 RMST 가 같으므로 정보 손실 없음). -#}
{%- set unlimited = var('ltv_unlimited', true) -%}
{%- set horizon = var('ltv_horizon_max', 480) -%}
{%- set learn_start = var('ltv_learn_start', none) -%}
with base as (
    select
        -- 🆕 [O233] 입력 = 최종 중단 기준(현업 회신 「재후원 포함」) · 최초 기준 = OBS_TENURE_MONTHS·IS_STOPPED_OBS
        OBS_TENURE_MONTHS_LAST                              as T,
        IS_STOPPED_OBS_LAST                                 as E,
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
-- 🆕 [O249] 계산형 상한 1값 = CEIL(관측 중 회원 평균 유지개월) · 셀 무관(전체 모집단)
cap as (
    select CAST(CEIL(AVG(IFF(E = 0, T, NULL))) AS NUMBER(4,0)) as CAP_M from base
),
ax as (
    select '전체' as AXIS_TYPE, '전체' as AXIS_VALUE, T, E from base
    union all select '개발인입경로', INFLOW_PATH, T, E from base
    union all select '캠페인카테고리', CMPGN_CTGR, T, E from base
    union all select '캠페인유형1', CMPGN_TYPE1, T, E from base
    union all select '캠페인유형2', CMPGN_TYPE2, T, E from base
),
cell as (
    select AXIS_TYPE, AXIS_VALUE, COUNT(*) as COHORT_MEMBERS, SUM(E) as STOPPED_MEMBERS_TOTAL, MAX(T) as MAX_T
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
    select c.AXIS_TYPE, c.AXIS_VALUE, c.COHORT_MEMBERS, c.STOPPED_MEMBERS_TOTAL, c.MAX_T, m.ELAPSED_MONTH,
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
    CAST(AXIS_TYPE AS VARCHAR(20))                                  as AXIS_TYPE,
    CAST(AXIS_VALUE AS VARCHAR(200))                                as AXIS_VALUE,
    CAST(ELAPSED_MONTH AS NUMBER(4,0))                              as ELAPSED_MONTH,
    CAST(AT_RISK AS NUMBER(18,0))                                   as AT_RISK_MEMBERS,
    CAST(D AS NUMBER(18,0))                                         as STOP_MEMBERS,
    CAST(N_END - D AS NUMBER(18,0))                                 as CENSORED_MEMBERS,
    CAST(SURV_START AS NUMBER(12,10))                               as SURV_START,
    CAST(SURV_END AS NUMBER(12,10))                                 as SURV_END,
    CAST(RMST_CUM AS NUMBER(10,4))                                  as RMST_CUM,
    CAST(CASE
         WHEN ELAPSED_MONTH = cap.CAP_M - 1 THEN cap.CAP_M
         {%- if unlimited %}
         WHEN ELAPSED_MONTH = MAX_T THEN 9999
         {%- endif %}
         END AS NUMBER(4,0))                                        as LTV_CAP_AVG_ACTIVE_MONTHS,
    CAST(COHORT_MEMBERS AS NUMBER(18,0))                            as COHORT_MEMBERS,
    CAST(STOPPED_MEMBERS_TOTAL AS NUMBER(18,0))                     as STOPPED_MEMBERS_TOTAL,
    COHORT_MEMBERS >= {{ var('ltv_min_cell', 500) }}                as IS_CELL_RELIABLE,
    CAST('{{ learn_start if learn_start else "전체 이력" }}' AS VARCHAR(20)) as LEARN_START,
    {{ gold_meta('CRM') }}
from s3
cross join cap
