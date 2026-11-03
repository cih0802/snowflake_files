{% snapshot snp_crm_tc_cmmn_cd %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='CD_ID',
      strategy='check',
      check_cols=['CD_NM', 'CD_DC', 'SORT_ORDR', 'USE_YN'],
      tags=['tier2', 'snapshot']
    )
}}

select
    CD_ID,
    CD_NM,
    CD_DC,
    SORT_ORDR,
    RM,
    USE_YN,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TC_CMMN_CD') }}

{% endsnapshot %}
