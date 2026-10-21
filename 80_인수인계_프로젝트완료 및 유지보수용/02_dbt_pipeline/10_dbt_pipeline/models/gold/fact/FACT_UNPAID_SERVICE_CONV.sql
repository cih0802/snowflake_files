-- =============================================================================
-- Purpose    : 미납서비스 클릭회원 × 이후 납입 전환 팩트 (공#81 미납서비스 전환율)
-- Target     : GOLD.FACT_UNPAID_SERVICE_CONV (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref BIGQUERY_EVENT, ref CRM_PAYMENT_BILLING
-- Issue      : O239, O237-C
-- =============================================================================
-- FACT_UNPAID_SERVICE_CONV: 미납서비스 클릭회원 × 이후 납입 전환 팩트 (공#81 미납서비스 전환율)
--  [2026-10-16 O239 · G1 잔여 ② · 사용자 지시 = 추천안 2개 동시 구현 → Agent 실사용 후 현업 결정]
--   정의(지표사전 공#81) = 납입회원(명) ÷ 미납서비스 클릭회원(명) × 100 · 「클릭회원 명수는 GA 값」.
--   클릭회원 = GA 이벤트 URL 의 memnum= 값(발송 링크로 들어온 회원 · DIM_MEMBER.MEMBER_DK 와 같은 체계).
--   grain = CLICK_MONTH_KEY × MEMBER_DK × SVC_SCOPE(그 달 첫 클릭 1행).
--   추천안 2개(WARN: SV 는 SVC_SCOPE 를 반드시 하나로 고정한다 — 두 범위는 겹친다):
--     · 안A(좁음) = SVC_SCOPE 'A' = 미납 안내 페이지(unpayed*)만 · 전환 = 미납분 납입(청구월 < 클릭월) ARREAR_PAID_D30_FLAG.
--     · 안B(넓음) = SVC_SCOPE 'B' = 안A 페이지 + 결제정보 변경 빠른 페이지(paymentchange_quick·paymentchange_check) ·
--       전환 = 모든 납입 PAID_D30_FLAG.
--     5일·30일 플래그를 둘 다 싣는다 — 창 길이는 현업 확인 대상(O237-C 클릭 전환 창과 같은 질문).
--   WARN: 창 = 첫 클릭일 D+0 ~ D+N(클릭 당일 납입 포함) — O237-C 개발 전환(D+1~)과 다르다: 미납 안내는 당일 납부가 본 목적이다.
--   WARN: 적재 = 일반 GOLD fact 경로(TRUNCATE 후 전량 재계산 · RANGED_FACTS 비등재).
{%- set PAGES_A = ["'%/unpayed%'"] -%}
{%- set PAGES_B_EXTRA = ["'%/paymentchange_quick.gn'", "'%/paymentchange_check.gn'"] %}
{{ config(
    tags=['gold_ready']
) }}

with clk as (
    select
        REGEXP_SUBSTR(PAGE_LOCATION, '[?&]memnum=([0-9]+)', 1, 1, 'ie', 1)   as MEMBER_DK,
        EVENT_DT,
        SPLIT_PART(PAGE_LOCATION, '?', 1) ilike any ({{ PAGES_A | join(', ') }}) as IS_SCOPE_A
    from {{ ref('BIGQUERY_EVENT') }}
    where SPLIT_PART(PAGE_LOCATION, '?', 1) ilike any ({{ (PAGES_A + PAGES_B_EXTRA) | join(', ') }})
),
sc as (
    select 'A' as SVC_SCOPE, MEMBER_DK, TO_NUMBER(TO_CHAR(EVENT_DT, 'YYYYMM')) as CLICK_MONTH_KEY,
           MIN(EVENT_DT) as FIRST_CLICK_DT, COUNT(*) as CLICK_EVENT_CNT
    from clk
    where IS_SCOPE_A and MEMBER_DK is not null
    group by 1, 2, 3
    union all
    select 'B', MEMBER_DK, TO_NUMBER(TO_CHAR(EVENT_DT, 'YYYYMM')),
           MIN(EVENT_DT), COUNT(*)
    from clk
    where MEMBER_DK is not null
    group by 1, 2, 3
),
pay as (
    select MBER_NO as MEMBER_DK, PAY_DE, MBRFEE_MT, PAY_AMT
    from {{ ref('CRM_PAYMENT_BILLING') }}
    where PAY_AMT > 0
      and PAY_DE >= (select MIN(FIRST_CLICK_DT) from sc)
)

select
    sc.CLICK_MONTH_KEY                                                    as CLICK_MONTH_KEY,
    sc.MEMBER_DK                                                          as MEMBER_DK,
    sc.SVC_SCOPE                                                          as SVC_SCOPE,
    COALESCE({{ date_sk('sc.FIRST_CLICK_DT') }}, 0)                       as FIRST_CLICK_DATE_SK,
    sc.CLICK_EVENT_CNT                                                    as CLICK_EVENT_CNT,
    MAX(IFF(p.PAY_DE <= DATEADD(day, 5, sc.FIRST_CLICK_DT), 1, 0))        as PAID_D5_FLAG,
    MAX(IFF(p.PAY_DE is not null, 1, 0))                                  as PAID_D30_FLAG,
    MAX(IFF(p.MBRFEE_MT < TO_CHAR(sc.FIRST_CLICK_DT, 'YYYYMM')
            and p.PAY_DE <= DATEADD(day, 5, sc.FIRST_CLICK_DT), 1, 0))    as ARREAR_PAID_D5_FLAG,
    MAX(IFF(p.MBRFEE_MT < TO_CHAR(sc.FIRST_CLICK_DT, 'YYYYMM'), 1, 0))    as ARREAR_PAID_D30_FLAG,
    COALESCE(SUM(p.PAY_AMT), 0)                                           as PAID_AMT_D30,
    {{ gold_meta('BIGQUERY+CRM') }}
from sc
left join pay p
       on p.MEMBER_DK = sc.MEMBER_DK
      and p.PAY_DE between sc.FIRST_CLICK_DT and DATEADD(day, 30, sc.FIRST_CLICK_DT)
group by sc.CLICK_MONTH_KEY, sc.MEMBER_DK, sc.SVC_SCOPE, sc.FIRST_CLICK_DT, sc.CLICK_EVENT_CNT
