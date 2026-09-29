-- FACT_MEMBER_SPONSORSHIP_SPAN: 회원×후원약정 기간/스팬 팩트 (약정별 시작~중단 기간 및 대표 캠페인 귀속)
-- Co-authored with CoCo
{{ config(
    materialized='incremental',
    unique_key=['MEMBER_DK', 'SPNSR_BSNS_NO'],
    tags=['gold_pending']
) }}

with span as (
    select * from {{ ref('CRM_MEMBER_SPONSOR_SPAN') }}
),

-- 대표캠페인: 우선순위 신규(1) > 그 외, 그 안에서 최초일자·최소일련번호
campaign_pick as (
    select
        SPNSR_BSNS_NO,
        CMPGN_CD,
        MBER_INFLOW_PATH_CD, MBER_INFLOW_PATH_NM,
        CMPGN_CTGR_CD, CMPGN_CTGR_NM,
        CMPGN_TYPE1_BSN, CMPGN_TYPE1_NM,
        CMPGN_TYPE2_BSN, CMPGN_TYPE2_NM,
        MKTG_CMPGN_NM, MK_CMPGN_NM,
        CMMN_BRND, CMMN_BRND_NM,
        MKTG_UTM, MKTG_UTM_NM,
        SPNSR_DIV_CD, SPNSR_DIV_NM,
        CPR_DIV_CD, CPR_DIV_NM,
        BRND_NM, PARENT_CAMPAIGN_NAME, PROMO_METHOD_NAME,
        row_number() over (
            partition by SPNSR_BSNS_NO
            order by iff(DVLP_DIV_CD = '1', 0, 1), OCCRRNC_DE, SER_NO
        ) as rn
    from {{ ref('CRM_MEMBER_DEV') }}
),
campaign_rep as (
    select
        SPNSR_BSNS_NO, CMPGN_CD,
        MBER_INFLOW_PATH_CD, MBER_INFLOW_PATH_NM,
        CMPGN_CTGR_CD, CMPGN_CTGR_NM,
        CMPGN_TYPE1_BSN, CMPGN_TYPE1_NM,
        CMPGN_TYPE2_BSN, CMPGN_TYPE2_NM,
        MKTG_CMPGN_NM, MK_CMPGN_NM,
        CMMN_BRND, CMMN_BRND_NM,
        MKTG_UTM, MKTG_UTM_NM,
        SPNSR_DIV_CD, SPNSR_DIV_NM,
        CPR_DIV_CD, CPR_DIV_NM,
        BRND_NM, PARENT_CAMPAIGN_NAME, PROMO_METHOD_NAME
    from campaign_pick
    where rn = 1
),

campaign_multi as (
    select SPNSR_BSNS_NO, count(distinct CMPGN_CD) as DISTINCT_CAMPAIGNS
    from {{ ref('CRM_MEMBER_DEV') }}
    group by SPNSR_BSNS_NO
)

select
    span.MBER_NO                                    as MEMBER_DK,
    span.SPNSR_NO,
    span.SPNSR_BSNS_NO,
    coalesce(dsp.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,
    coalesce(dcp.CAMPAIGN_SK, 0)                     as CAMPAIGN_SK,
    iff(cm.DISTINCT_CAMPAIGNS > 1, TRUE, FALSE)      as IS_MULTI_CAMPAIGN,
    span.START_MONTH_KEY,
    span.DSCNTC_MONTH_KEY,
    span.SPNSR_AMT,
    cr.MBER_INFLOW_PATH_CD                           as ACQ_MBER_INFLOW_PATH_CD,
    cr.MBER_INFLOW_PATH_NM                           as ACQ_MBER_INFLOW_PATH_NM,
    cr.CMPGN_CTGR_CD                                 as ACQ_CMPGN_CTGR_CD,
    cr.CMPGN_CTGR_NM                                 as ACQ_CMPGN_CTGR_NM,
    cr.CMPGN_TYPE1_BSN                               as ACQ_CMPGN_TYPE1_BSN,
    cr.CMPGN_TYPE1_NM                                as ACQ_CMPGN_TYPE1_NM,
    cr.CMPGN_TYPE2_BSN                               as ACQ_CMPGN_TYPE2_BSN,
    cr.CMPGN_TYPE2_NM                                as ACQ_CMPGN_TYPE2_NM,
    cr.MKTG_CMPGN_NM                                 as ACQ_MKTG_CMPGN_CD,
    cr.MK_CMPGN_NM                                   as ACQ_MKTG_CMPGN_NM,
    cr.CMMN_BRND                                     as ACQ_CMMN_BRND,
    cr.CMMN_BRND_NM                                  as ACQ_CMMN_BRND_NM,
    cr.MKTG_UTM                                      as ACQ_MKTG_UTM,
    cr.MKTG_UTM_NM                                   as ACQ_MKTG_UTM_NM,
    cr.SPNSR_DIV_CD                                  as ACQ_SPNSR_DIV_CD,
    cr.SPNSR_DIV_NM                                  as ACQ_SPNSR_DIV_NM,
    cr.CPR_DIV_CD                                    as ACQ_CPR_DIV_CD,
    cr.CPR_DIV_NM                                    as ACQ_CPR_DIV_NM,
    cr.BRND_NM                                       as ACQ_BRAND,
    cr.PARENT_CAMPAIGN_NAME                          as ACQ_PARENT_CAMPAIGN_NAME,
    cr.PROMO_METHOD_NAME                             as ACQ_PROMO_METHOD_NAME,
    {{ gold_meta('CRM') }},
    -- 🆕 [2026-09-29 O188-F] 후원 단위 가입경로(원천 TM_MM_FDRM_MBER_SPNSR.JOIN_PATH_CD · 코드군 MM014)
    --   회원 단위 가입경로(DIM_MEMBER.ENROLL_PATH_NAME · MBER_INFO)와 **다른 grain** 이다 — 한 회원의 후원건마다 다를 수 있다.
    span.JOIN_PATH_CD                                as SPNSR_JOIN_PATH_CD,
    jp.DTL_CD_NM                                     as SPNSR_JOIN_PATH_NM,
    -- 🆕 [2026-09-29 O189-B · 2차-B 1단] 후원(SPNSR_NO) 등록 원천 캠페인·실적부서 raw(DDL 선행 적용 완료)
    --   🔴 대표캠페인(CAMPAIGN_SK = 개발사건 규칙 · campaign_rep)과 **다른 축**이다 — 값이 갈릴 수 있고 합치지 않는다.
    span.CMPGN_CD                                    as SPNSR_CMPGN_CD,
    span.ACMSLT_DEPT_CD                              as SPNSR_ACMSLT_DEPT_CD
from span
left join campaign_rep cr
       on cr.SPNSR_BSNS_NO = span.SPNSR_BSNS_NO
left join campaign_multi cm
       on cm.SPNSR_BSNS_NO = span.SPNSR_BSNS_NO
left join {{ ref('DIM_SPONSORSHIP') }} dsp
       on dsp.SPONSORSHIP_BK = span.SPNSR_BSNS_ID
left join {{ ref('DIM_CAMPAIGN') }} dcp
       on dcp.CAMPAIGN_BK = cr.CMPGN_CD
-- 🆕 O188-F MM014 라벨 — (CD_ID, DTL_CD_ID) 유일이라 fan-out 0
left join {{ ref('CRM_CODE') }} jp
       on jp.CD_ID = 'MM014' and jp.DTL_CD_ID = span.JOIN_PATH_CD
