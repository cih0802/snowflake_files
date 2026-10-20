{% snapshot snp_crm_tm_cm_cmpgn_mng %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='CMPGN_CD',
      strategy='timestamp',
      updated_at='LAST_UPDT_DT',
      tags=['tier1', 'snapshot']
    )
}}

select
    CMPGN_CD,
    CMPGN_NM,
    UPPER_CMPGN_CD,
    UPPER_CMPGN_YN,
    SPNSR_DIV_CD,
    CPR_DIV_CD,
    CMPGN_TRGET_CD,
    USE_DEPT_CD,
    USE_SCOPE,
    SPNSR_ENTRPRS_ID,
    BRND_ID,
    PR_MTH_CD,
    CMPGN_STRT_DE,
    MBRFEE_BNKB_LIST,
    INICIS_ACNT_NO,
    USE_YN,
    REFER_URL,
    SPNSR_BSNS_ID,
    CMPGN_DC,
    EMRGNCY_AID_BPLC_CD,
    CMPGN_PRPT_YN,
    ATCHFL_ID,
    RM,
    MBER_INFLOW_PATH_CD,
    CMPGN_CTGR_CD,
    CMPGN_TYPE1_BSN,
    CMPGN_TYPE2_BSN,
    MKTG_CMPGN_NM,
    CMMN_BRND,
    MKTG_UTM,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_CM_CMPGN_MNG') }}

{% endsnapshot %}
