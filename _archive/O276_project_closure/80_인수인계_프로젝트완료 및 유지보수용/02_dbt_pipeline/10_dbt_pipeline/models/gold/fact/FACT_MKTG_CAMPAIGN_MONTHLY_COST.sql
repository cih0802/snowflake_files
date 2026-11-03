-- =============================================================================
-- Purpose    : 마케팅캠페인 × 월 비용·개발 결합 팩트 · [2026-10-28 O266 · 사용자 결정 ㉡-a]
-- Target     : GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계) · 선행 = 46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql [D0]·[D1]
-- Depends on : ref FACT_AD_PERFORMANCE, ref FACT_EXPENSE_RESOLUTION, ref CRM_CAMPAIGN, ref DIM_MARKETING_CAMPAIGN, ref FACT_MEMBER_EVENT(O270), source mstr.F_MM_SPNSR_DVLP_SUM
-- Issue      : O266, O45, O225-B
-- =============================================================================
-- FACT_MKTG_CAMPAIGN_MONTHLY_COST: 「마케팅캠페인별 광고비 / 개발건수 / 제작비」를 한 표로 답하는 결합 팩트.
-- grain: MKTG_CAMPAIGN_SK × MONTH_KEY(YYYYMM). MKTG_CAMPAIGN_SK = 0 = 마케팅캠페인 미연결 버킷(버리지 않는다).
-- 왜 신설했나 — 광고(SV_AD)·개발(MSTR)·제작비(SV_EXPENSE_RESOLUTION)가 SV 3개로 나뉘어 Agent 가 표 3개를 냈다(현업 피드백 2).
--   세 원천은 모두 같은 결합축(DIM_MARKETING_CAMPAIGN)에 이미 닿는다 ⇒ 월 단위로 미리 접어 FULL OUTER 로 붙인다.
-- 원천별 정의:
--   광고비 = FACT_AD_PERFORMANCE.AD_COST(3원천 합 · 출처유형 3분해 열 동반) · 정산액 = LAST_STMT_AMT(DIGITAL 전용)
--   제작비 = FACT_EXPENSE_RESOLUTION.SUM_AMT 중 콘텐츠구분자(=세부캠페인코드) 기재분(MKTG_CAMPAIGN_SK <> 0) — [O270] 현업 확정 규칙(데분_2)
--                 WARN: 미기재분(NULL·「-」)은 캠페인을 알 수 없어 이 팩트에 넣지 않는다(0 버킷에 넣으면 「미연결 제작비」로 오독된다).
--   최종 광고비 = [O270] 디지털 LAST_STMT_AMT · 영상 AD_COST(=LAST_AD_COST) · 방송 TOT_COST 합(현업 데분_6) · 기존 AD_COST(편성비 기준)는 그대로 둔다.
--   개발(건) = MSTR F_MM_SPNSR_DVLP_SUM.SPNSR_AMT_CNT 중 DVLP_DIV_CD 1·2·4(신규·증액·재후원) — MSTR 정의(후원금액 ÷ 10,000)
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
        SUM(LAST_STMT_AMT)                                          as LAST_STMT_AMT,
        --  [O270 · 현업 데분_1·6] 최종 광고비 = 디지털 최종정산금액 · 영상 최종광고비 · 방송 총비용(같은 개념 · 현업 확정)
        --   NULL 은 0 으로 채우지 않는다(R2-7) — SUM 이 건너뛴 행 수를 FINAL_AD_COST_NULL_ROWS 로 함께 낸다.
        SUM(IFF(AD_SOURCE_TYPE = 'REBROADCAST', TOT_COST, NULL))    as AD_COST_REBROADCAST_TOT,
        SUM(CASE AD_SOURCE_TYPE
                WHEN 'DIGITAL'     THEN LAST_STMT_AMT
                WHEN 'VIDEO'       THEN AD_COST
                WHEN 'REBROADCAST' THEN TOT_COST
            END)                                                    as FINAL_AD_COST,
        COUNT_IF(CASE AD_SOURCE_TYPE
                WHEN 'DIGITAL'     THEN LAST_STMT_AMT
                WHEN 'VIDEO'       THEN AD_COST
                WHEN 'REBROADCAST' THEN TOT_COST
            END IS NULL)                                            as FINAL_AD_COST_NULL_ROWS
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
--  [O270 · 현업 데분_1㉠] CRM 개발(건) = FACT_MEMBER_EVENT.DEV_CNT(금액 ÷ 10,000 · 상계 규칙 적용 · 굿네이버스 기본 건수 정의)
--   결합 = MKTG_CMPGN_CD_AT_EVENT(사건 시점 마케팅캠페인 코드) = DIM_MARKETING_CAMPAIGN.MKTG_CAMPAIGN_BK · 미연결 = SK 0
crm as (
    select
        COALESCE(mk.MKTG_CAMPAIGN_SK, 0)                            as MKTG_CAMPAIGN_SK,
        FLOOR(e.DATE_SK / 100)                                      as MONTH_KEY,
        ROUND(SUM(e.DEV_CNT), 4)                                    as DEV_CNT_CRM,
        ROUND(SUM(IFF(e.DVLP_DIV_CD = '1', e.DEV_CNT, 0)), 4)       as NEW_DEV_CNT_CRM
    from {{ ref('FACT_MEMBER_EVENT') }} e
    left join {{ ref('DIM_MARKETING_CAMPAIGN') }} mk
           on TO_VARCHAR(mk.MKTG_CAMPAIGN_BK) = TO_VARCHAR(e.MKTG_CMPGN_CD_AT_EVENT)
          and mk.MKTG_CAMPAIGN_SK <> 0
    where e.EVENT_TYPE = 'DEV'
      and e.DVLP_DIV_CD in ('1', '2', '4')
      and e.DATE_SK > 0
    group by 1, 2
),
k as (
    select MKTG_CAMPAIGN_SK, MONTH_KEY from ad
    union
    select MKTG_CAMPAIGN_SK, MONTH_KEY from prod
    union
    select MKTG_CAMPAIGN_SK, MONTH_KEY from dev
    union
    select MKTG_CAMPAIGN_SK, MONTH_KEY from crm
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
    ad.AD_COST_REBROADCAST_TOT,
    ad.FINAL_AD_COST,
    ad.FINAL_AD_COST_NULL_ROWS,
    dev.DEV_CNT_MSTR,
    dev.NEW_DEV_CNT_MSTR,
    dev.DEV_MEMBERS_MSTR,
    crm.DEV_CNT_CRM,
    crm.NEW_DEV_CNT_CRM,
    {{ gold_meta('MULTI') }}
from k
left join ad   on ad.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK   and ad.MONTH_KEY = k.MONTH_KEY
left join prod on prod.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK and prod.MONTH_KEY = k.MONTH_KEY
left join dev  on dev.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK  and dev.MONTH_KEY = k.MONTH_KEY
left join crm  on crm.MKTG_CAMPAIGN_SK = k.MKTG_CAMPAIGN_SK  and crm.MONTH_KEY = k.MONTH_KEY
where k.MONTH_KEY is not null
