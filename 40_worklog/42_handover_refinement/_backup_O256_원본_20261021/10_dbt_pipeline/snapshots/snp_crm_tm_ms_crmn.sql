{% snapshot snp_crm_tm_ms_crmn %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='CRMN_CD',
      strategy='timestamp',
      updated_at='LAST_UPDT_DT',
      tags=['tier2', 'snapshot']
    )
}}

select
    CRMN_CD,
    CRMN_DIV_CD,
    CRMN_TIT,
    CRMN_PLACE_NM,
    BRNCH_DEPT_ID,
    ATCHFL_ID,
    SITE_URL,
    CRMN_STRT_DE,
    CRMN_END_DE,
    CRMN_PART_STRT_DE,
    CRMN_PART_END_DE,
    TAT,
    RCRIT_PSNNL_CO,
    RESRCE_SRVC_FG,
    CPR_DIV_CD,
    ENTRPS_CD,
    RM,
    CRMN_CTNT,
    USE_YN,
    PART_USE_YN,
    TMPLAT_ID,
    TMPLAT_TIT,
    TMPLAT_PART_ID,
    TMPLAT_PART_TIT,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_MS_CRMN') }}

{% endsnapshot %}
