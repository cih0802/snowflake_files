{% snapshot snp_crm_tm_ms_email_tmplat_mng %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='TMPLAT_KEY',
      strategy='timestamp',
      updated_at='LAST_UPDT_DT',
      tags=['tier2', 'snapshot']
    )
}}

select
    TMPLAT_KEY,
    CPR_DIV_CD,
    SNDNG_CD_ID,
    SNDNG_DTL_CD_ID,
    ATMC_YN,
    TIT,
    EMAIL_CTNT,
    WRITNG_DEPT_ID,
    WRITNG_DEPT_NM,
    CHRG_DEPT_ID,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_MS_EMAIL_TMPLAT_MNG') }}

{% endsnapshot %}
