{% snapshot snp_crm_tc_cmmn_dtl_cd %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='CMMN_DTL_CD_SK',
      strategy='check',
      check_cols=['DTL_CD_NM', 'DTL_CD_DC', 'SORT_ORDR', 'USE_YN', 'CD_ATRB1', 'CD_ATRB2', 'CD_ATRB3', 'UPPER_CD_ID'],
      tags=['tier2', 'snapshot']
    )
}}

select
    MD5(COALESCE(CD_ID,'') || '|' || COALESCE(DTL_CD_ID,'')) as CMMN_DTL_CD_SK,
    CD_ID,
    DTL_CD_ID,
    DTL_CD_NM,
    DTL_CD_DC,
    SORT_ORDR,
    RM,
    USE_YN,
    CD_ATRB1,
    CD_ATRB2,
    CD_ATRB3,
    UPPER_CD_ID,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TC_CMMN_DTL_CD') }}

{% endsnapshot %}
