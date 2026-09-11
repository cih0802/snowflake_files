-- FACT_MEMBER_EVENT: 회원 생애주기 사건 팩트 (개발/약정 ∪ 후원중단 이벤트) — 가입, 증액, 감액, 재후원, 중단 등 생애 이벤트 추적
-- Co-authored with CoCo


with org_lookup as (
    select ORG_DK, ORG_SK from GN_DW.GOLD.DIM_ORG
),
campaign_valid as (
    select CMPGN_CD from GN_DW.SILVER.CRM_CAMPAIGN
),
code_ageband as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM014'
),
code_sex as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM013'
),
spb_lookup as (
    select SPONSORSHIP_BK, SPONSORSHIP_SK from GN_DW.GOLD.DIM_SPONSORSHIP
),

dev as (
    select
        COALESCE(CASE WHEN TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD') BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD'), 'YYYYMMDD')) END, 0)  as DATE_SK,
        MBER_NO                                             as MEMBER_DK,
        'DEV'                                               as EVENT_TYPE,
        case when c.CMPGN_CD is not null
             then ABS(HASH(COALESCE(CAST(d.CMPGN_CD AS VARCHAR), '∅')))
             else 0
        end                                                 as CAMPAIGN_SK,
        COALESCE(sp.SPONSORSHIP_SK, 0)                       as SPONSORSHIP_SK,
        COALESCE(og.ORG_SK, 0)                              as ORG_SK,
        0 as REASON_SK,
        d.DVLP_DIV_CD                                       as DVLP_DIV_CD,
        d.DVLP_DIV_NM                                       as DVLP_DIV_NM,
        d.SPNSR_AMT                                         as SPNSR_AMT,
        case when d.DVLP_DIV_CD in ('1','2','4') then 1 else 0 end as DEV_CNT,
        case when d.DVLP_DIV_CD in ('1','2','4') then 1 else 0 end as DEV_MEMBERS,
        0 as STOP_CNT, 0 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD')                  as JOIN_DATE,
        CAST(NULL AS DATE)                                  as STOP_DATE,
        CAST(NULL AS VARCHAR)                               as STOP_REASON,
        CAST(NULL AS VARCHAR)                               as STOP_CHANNEL,
        CAST(NULL AS VARCHAR)                               as STOP_REASON_NM,
        CAST(NULL AS VARCHAR)                               as STOP_CHANNEL_NM,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG,
        d.AGE                                               as AGE_AT_EVENT,
        cab.DTL_CD_NM                                       as AGE_BAND_AT_EVENT,
        d.AREA_CD                                           as AREA_CD_AT_EVENT,
        d.AREA_NM                                           as REGION_AT_EVENT,
        d.SEX                                               as SEX_AT_EVENT,
        csx.DTL_CD_NM                                       as GENDER_AT_EVENT,
        case when d.DVLP_DIV_CD = '5' then 1 else 0 end      as CAMPAIGN_STOP_CNT,
        d.MBER_INFLOW_PATH_CD                                as MBER_INFLOW_PATH_CD_AT_EVENT,
        d.MBER_INFLOW_PATH_NM                                as MBER_INFLOW_PATH_NM_AT_EVENT,
        d.CMPGN_CTGR_CD                                      as CMPGN_CTGR_CD_AT_EVENT,
        d.CMPGN_CTGR_NM                                      as CMPGN_CTGR_NM_AT_EVENT,
        d.CMPGN_TYPE1_BSN                                    as CMPGN_TYPE1_BSN_AT_EVENT,
        d.CMPGN_TYPE1_NM                                     as CMPGN_TYPE1_NM_AT_EVENT,
        d.CMPGN_TYPE2_BSN                                    as CMPGN_TYPE2_BSN_AT_EVENT,
        d.CMPGN_TYPE2_NM                                     as CMPGN_TYPE2_NM_AT_EVENT,
        d.MKTG_CMPGN_NM                                      as MKTG_CMPGN_CD_AT_EVENT,
        d.MK_CMPGN_NM                                        as MKTG_CMPGN_NM_AT_EVENT,
        d.CMMN_BRND                                          as CMMN_BRND_AT_EVENT,
        d.CMMN_BRND_NM                                       as CMMN_BRND_NM_AT_EVENT,
        d.MKTG_UTM                                           as MKTG_UTM_AT_EVENT,
        d.MKTG_UTM_NM                                        as MKTG_UTM_NM_AT_EVENT,
        d.SPNSR_DIV_CD                                       as SPNSR_DIV_CD_AT_EVENT,
        d.SPNSR_DIV_NM                                       as SPNSR_DIV_NM_AT_EVENT,
        d.CPR_DIV_CD                                         as CPR_DIV_CD_AT_EVENT,
        d.CPR_DIV_NM                                         as CPR_DIV_NM_AT_EVENT,
        d.BRND_NM                                            as BRAND_AT_EVENT,
        d.PARENT_CAMPAIGN_NAME                               as PARENT_CAMPAIGN_NAME_AT_EVENT,
        d.PROMO_METHOD_NAME                                  as PROMO_METHOD_NAME_AT_EVENT
    from GN_DW.SILVER.CRM_MEMBER_DEV d
    left join campaign_valid c on d.CMPGN_CD = c.CMPGN_CD
    left join code_ageband   cab on to_varchar(d.AGE) = cab.DTL_CD_ID
    left join code_sex       csx on d.SEX = csx.DTL_CD_ID
    left join org_lookup     og on og.ORG_DK = ABS(HASH(d.ACMSLT_DEPT_CD))
    left join spb_lookup     sp on sp.SPONSORSHIP_BK = d.SPNSR_BSNS_ID
),

stop as (
    select
        COALESCE(CASE WHEN TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD') BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD'), 'YYYYMMDD')) END, 0) as DATE_SK,
        MBER_NO                                             as MEMBER_DK,
        'STOP'                                              as EVENT_TYPE,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK,
        0 as ORG_SK,
        case when NULLIF(TRIM(DSCNTC_RSN_CD),'') is not null
             then ABS(HASH(COALESCE(CAST('MM005' AS VARCHAR), '∅') || '‖' || COALESCE(CAST(NULLIF(TRIM(DSCNTC_RSN_CD),'') AS VARCHAR), '∅')))
             else 0
        end                                                 as REASON_SK,
        CAST(NULL AS VARCHAR)                               as DVLP_DIV_CD,
        CAST(NULL AS VARCHAR)                               as DVLP_DIV_NM,
        CAST(NULL AS NUMBER(18,0))                          as SPNSR_AMT,
        0 as DEV_CNT, 0 as DEV_MEMBERS,
        1 as STOP_CNT, 1 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        CAST(NULL AS DATE)                                  as JOIN_DATE,
        TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD')             as STOP_DATE,
        DSCNTC_RSN_CD                                       as STOP_REASON,
        DSCNTC_PATH                                         as STOP_CHANNEL,
        DSCNTC_RSN_NM                                       as STOP_REASON_NM,
        DSCNTC_PATH_NM                                      as STOP_CHANNEL_NM,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG,
        CAST(NULL AS NUMBER(2,0))                           as AGE_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as AGE_BAND_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as AREA_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as REGION_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as SEX_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as GENDER_AT_EVENT,
        0                                                   as CAMPAIGN_STOP_CNT,
        CAST(NULL AS NUMBER(38,0))                          as MBER_INFLOW_PATH_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as MBER_INFLOW_PATH_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMPGN_CTGR_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMPGN_CTGR_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMPGN_TYPE1_BSN_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMPGN_TYPE1_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMPGN_TYPE2_BSN_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMPGN_TYPE2_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as MKTG_CMPGN_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as MKTG_CMPGN_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMMN_BRND_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMMN_BRND_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as MKTG_UTM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as MKTG_UTM_NM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as SPNSR_DIV_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as SPNSR_DIV_NM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CPR_DIV_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CPR_DIV_NM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as BRAND_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as PARENT_CAMPAIGN_NAME_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as PROMO_METHOD_NAME_AT_EVENT
    from GN_DW.SILVER.CRM_MEMBER_DISCONTINUE
),

unioned as (
    select * from dev
    union all
    select * from stop
)

select
    DATE_SK, MEMBER_DK, EVENT_TYPE, CAMPAIGN_SK, SPONSORSHIP_SK, ORG_SK, REASON_SK,
    DVLP_DIV_CD, DVLP_DIV_NM, SPNSR_AMT,
    DEV_CNT, DEV_MEMBERS, STOP_CNT, STOP_MEMBERS, UNPAID_STOP_CNT, UNPAID_STOP_MEMBERS,
    JOIN_DATE, STOP_DATE, STOP_REASON, STOP_CHANNEL, STOP_REASON_NM, STOP_CHANNEL_NM, NEW_EXISTING_FLAG,
    AGE_AT_EVENT, AGE_BAND_AT_EVENT, AREA_CD_AT_EVENT, REGION_AT_EVENT,
    SEX_AT_EVENT, GENDER_AT_EVENT, CAMPAIGN_STOP_CNT,
    MBER_INFLOW_PATH_CD_AT_EVENT, MBER_INFLOW_PATH_NM_AT_EVENT,
    CMPGN_CTGR_CD_AT_EVENT, CMPGN_CTGR_NM_AT_EVENT,
    CMPGN_TYPE1_BSN_AT_EVENT, CMPGN_TYPE1_NM_AT_EVENT,
    CMPGN_TYPE2_BSN_AT_EVENT, CMPGN_TYPE2_NM_AT_EVENT,
    MKTG_CMPGN_CD_AT_EVENT, MKTG_CMPGN_NM_AT_EVENT,
    CMMN_BRND_AT_EVENT, CMMN_BRND_NM_AT_EVENT,
    MKTG_UTM_AT_EVENT, MKTG_UTM_NM_AT_EVENT,
    SPNSR_DIV_CD_AT_EVENT, SPNSR_DIV_NM_AT_EVENT,
    CPR_DIV_CD_AT_EVENT, CPR_DIV_NM_AT_EVENT,
    BRAND_AT_EVENT, PARENT_CAMPAIGN_NAME_AT_EVENT, PROMO_METHOD_NAME_AT_EVENT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '025f9ac5-d9be-4588-8381-cd1bfa260b2e'                    AS DW_BATCH_ID
from unioned