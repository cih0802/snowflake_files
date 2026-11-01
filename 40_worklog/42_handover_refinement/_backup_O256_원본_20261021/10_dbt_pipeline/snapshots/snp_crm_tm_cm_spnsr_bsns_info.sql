{% snapshot snp_crm_tm_cm_spnsr_bsns_info %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='SPNSR_BSNS_ID',
      strategy='check',
      check_cols=['SPNSR_DIV_CD', 'SPNSR_BSNS_NM', 'SPNSR_BSNS_ABRV_CD', 'DNTN_TY_CD', 'CPR_DIV_CD', 'USE_YN'],
      tags=['tier2', 'snapshot']
    )
}}

select
    SPNSR_BSNS_ID,
    SPNSR_DIV_CD,
    SPNSR_BSNS_NM,
    SPNSR_BSNS_ABRV_CD,
    DNTN_TY_CD,
    SORT_ORDR,
    CPR_DIV_CD,
    RM,
    USE_YN,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_CM_SPNSR_BSNS_INFO') }}

{% endsnapshot %}
