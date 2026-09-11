-- FACT_MEMBER_SPONSORSHIP_SPAN: 회원×후원약정 기간/스팬 팩트 (약정별 시작~중단 기간 및 대표 캠페인 귀속)
-- Co-authored with CoCo


with span as (
    select * from GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN
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
    from GN_DW.SILVER.CRM_MEMBER_DEV
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
    from GN_DW.SILVER.CRM_MEMBER_DEV
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
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '025f9ac5-d9be-4588-8381-cd1bfa260b2e'                    AS DW_BATCH_ID
from span
left join campaign_rep cr
       on cr.SPNSR_BSNS_NO = span.SPNSR_BSNS_NO
left join campaign_multi cm
       on cm.SPNSR_BSNS_NO = span.SPNSR_BSNS_NO
left join GN_DW.GOLD.DIM_SPONSORSHIP dsp
       on dsp.SPONSORSHIP_BK = span.SPNSR_BSNS_ID
left join GN_DW.GOLD.DIM_CAMPAIGN dcp
       on dcp.CAMPAIGN_BK = cr.CMPGN_CD