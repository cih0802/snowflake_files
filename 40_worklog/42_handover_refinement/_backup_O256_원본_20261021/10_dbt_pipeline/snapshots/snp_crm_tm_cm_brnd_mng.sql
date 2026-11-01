{% snapshot snp_crm_tm_cm_brnd_mng %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='BRND_ID',
      strategy='check',
      check_cols=['BRND_NM', 'USE_DEPT_CD', 'USE_YN', 'PR_MTH_LIST'],
      tags=['tier1', 'snapshot']
    )
}}

select
    BRND_ID,
    BRND_NM,
    USE_DEPT_CD,
    USE_YN,
    PR_MTH_LIST,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_CM_BRND_MNG') }}

{% endsnapshot %}
