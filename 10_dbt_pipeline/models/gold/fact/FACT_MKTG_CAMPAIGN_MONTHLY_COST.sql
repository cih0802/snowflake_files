-- =============================================================================
-- Purpose    : 마케팅캠페인 × 월 비용·개발 결합 팩트 · 🆕 [2026-10-28 O266 · 사용자 결정 ㉡-a]
-- Target     : GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계) · 선행 = 46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql [D0]·[D1]
-- Depends on : ref FACT_AD_PERFORMANCE, ref FACT_EXPENSE_RESOLUTION, ref CRM_CAMPAIGN, ref DIM_MARKETING_CAMPAIGN, source mstr.F_MM_SPNSR_DVLP_SUM
-- Issue      : O266, O45, O225-B
-- =============================================================================
-- FACT_MKTG_CAMPAIGN_MONTHLY_COST: 「마케팅캠페인별 광고비 / 개발건수 / 제작비」를 한 표로 답하는 결합 팩트.
-- grain: MKTG_CAMPAIGN_SK × MONTH_KEY(YYYYMM). MKTG_CAMPAIGN_SK = 0 = 마케팅캠페인 미연결 버킷(버리지 않는다).
-- 왜 신설했나 — 광고(SV_AD)·개발(MSTR)·제작비(SV_EXPENSE_RESOLUTION)가 SV 3개로 나뉘어 Agent 가 표 3개를 냈다(현업 피드백 2).
--   세 원천은 모두 같은 결합축(DIM_MARKETING_CAMPAIGN)에 이미 닿는다 ⇒ 월 단위로 미리 접어 FULL OUTER 로 붙인다.
-- 원천별 정의:
--   광고비      = FACT_AD_PERFORMANCE.AD_COST(3원천 합 · 출처유형 3분해 열 동반) · 정산액 = LAST_STMT_AMT(DIGITAL 전용)
--   제작비      = FACT_EXPENSE_RESOLUTION.SUM_AMT 중 세부캠페인코드 기재분(MKTG_CAMPAIGN_SK <> 0) — 세세목 필터 없음(사용자 가정)
--                 WARN: 미기재분(약 99%)은 캠페인을 알 수 없어 이 팩트에 넣지 않는다(0 버킷에 넣으면 「미연결 제작비」로 오독된다).
--   개발(건)    = MSTR F_MM_SPNSR_DVLP_SUM.SPNSR_AMT_CNT 중 DVLP_DIV_CD 1·2·4(신규·증액·재후원) — MSTR 정의(후원금액 ÷ 10,000)
--                 CMPGN_CD → CRM_CAMPAIGN → DIM_MARKETING_CAMPAIGN(FACT_EXPENSE_RESOLUTION 과 같은 cmk 규칙).
--   실측(ZS83821 · 코드 작성 시) = 광고 연결 512.6/601.9억 · 제작비 연결 33.0억 · MSTR 개발 이름 일치 884,455/885,881건.
-- WARN: 이 팩트의 개발단가는 「광고비 ÷ MSTR 개발(건)」이다 — SV_AD 공7(대행사 CRM 개발건 기준)과 분모가 다르다.
{{ config(
    tags=['gold_ready']
) }}

with cmk as (
    select
        c.CMPGN_CD,
        mk.MKTG_CAMPAIGN_SK
    from {{ ref('CRM_CAMPAIGN') }} c
    join {{ ref('DIM_MARKETING_CAMPAIGN') }} mk
      on mk.MKTG_CAMPAIGN_BK = TO_VARCHAR(c.MKTG_CMPGN_NM)
    group by 1, 2
    qualify row_number() over (partition by c.CMPGN_CD order by count(*) desc, mk.MKTG_CAMPAIGN_SK) = 1
),
ad as (
    select
        MKTG_CAMPAIGN_SK,
        FLOOR(PERF_DATE_SK / 100)                                   as MONTH_KEY,
        SUM(AD_COST)                                                as AD_COST,
        SUM(IFF(AD_SOURCE_TYPE = 'DIGITAL', AD_COST, 0))            as AD_COST_DIGITAL,
        SUM(IFF(AD_SOURCE_TYPE = 'VIDEO', AD_COST, 0))              as AD_COST_VIDEO,
        SUM(IFF(AD_SOURCE_TYPE = 'REBROADCAST', AD_COST, 0))        as AD_COST_REBROADCAST,
        SUM(LAST_STMT_AMT)                                          as LAST_STMT_AMT
    from {{ ref('FACT_AD_PERFORMANCE') }}
    where PERF_DATE_SK > 0
    group by 1, 2
),
prod as (
    select
        MKTG_CAMPAIGN_SK,
        FLOOR(DATE_SK / 100)                                        as MONTH_KEY,
        SUM(SUM_AMT)                                                as PROD_COST,
        COUNT(DISTINCT RESOLUTION_NO)                               as PROD_RESOLUTION_CNT
    from {{ ref('FACT_EXPENSE_RESOLUTION') }}
    where MKTG_CAMPAIGN_SK <> 0
      and DATE_SK > 0
    group by 1, 2
),
dev as (
    select
        COALESCE(cmk.MKTG_CAMPAIGN_SK, 0)                           as MKTG_CAMPAIGN_SK,
        TRY_TO_NUMBER(f.STRD_MT)                                    as MONTH_KEY,
        ROUND(SUM(f.SPNSR_AMT_CNT), 4)                              as DEV_CNT_MSTR,
        ROUND(SUM(IFF(f.DVLP_DIV_CD = '1', f.SPNSR_AMT_CNT, 0)), 4) as NEW_DEV_CNT_MSTR,
        COUNT(DISTINCT f.MBER_NO)                                   as DEV_MEMBERS_MSTR
    from {{ source('mstr', 'F_MM_SPNSR_DVLP_SUM') }} f
    left join cmk
           on cmk.CMPGN_CD = f.CMPGN_CD
    where f.DVLP_DIV_CD in ('1', '2', '4')
    group by 1, 2
),
k as (
    select MKTG_CAMPAIGN_SK, MONTH_KEY from ad
    union
    select MKTG_CAMPAIGN_SK, MONTH_KEY from prod
    union
    select MKTG_CAMPAIGN_SK, MONTH_KEY from dev
)

select
    k.MKTG_CAMPAIGN_SK,
    k.MONTH_KEY::NUMBER(6,0)            as MONTH_KEY,
    ad.AD_COST,
    ad.AD_COST_DIGITAL,
    ad.AD_COST_VIDEO,
    ad.AD_COST_REBROADCAST,
    ad.LAST_STMT_AMT,
    prod.PROD_COST,
    prod.PROD_RESOLUTION_CNT,
    dev.DEV_CNT_MSTR,
    dev.NEW_DEV_CNT_MSTR,
    dev.DEV_MEMBERS_MSTR,
    {{ gold_meta('MULTI') }}
from k
left join ad   on ad.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK   and ad.MONTH_KEY = k.MONTH_KEY
left join prod on prod.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK and prod.MONTH_KEY = k.MONTH_KEY
left join dev  on dev.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK  and dev.MONTH_KEY = k.MONTH_KEY
where k.MONTH_KEY is not null
