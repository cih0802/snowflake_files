{% snapshot snp_crm_tm_rm_bplc_mng %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='BPLC_CD',
      strategy='check',
      check_cols=['NATION_CD', 'BPLC_KORNM', 'BPLC_ENGNM', 'BSNS_STRT_DE', 'BSNS_END_DE', 'RELATNSP_BSNS_YN', 'RELATNSP_BSNS_DSCNTC_DE', 'GFTMNEY_PSBL_YN', 'LETTER_PSBL_YN', 'BPLC_MTCHG_MNG_YN'],
      tags=['tier1', 'snapshot']
    )
}}

select
    BPLC_CD,
    NATION_CD,
    BPLC_KORNM,
    BPLC_ENGNM,
    BSNS_STRT_DE,
    BSNS_END_DE,
    RELATNSP_BSNS_YN,
    RELATNSP_BSNS_DSCNTC_DE,
    GFTMNEY_PSBL_YN,
    LETTER_PSBL_YN,
    BPLC_DC,
    WTWK_FROM_DSTNC,
    CNCSN_RSN,
    BPLC_MTCHG_MNG_YN,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_RM_BPLC_MNG') }}

{% endsnapshot %}
