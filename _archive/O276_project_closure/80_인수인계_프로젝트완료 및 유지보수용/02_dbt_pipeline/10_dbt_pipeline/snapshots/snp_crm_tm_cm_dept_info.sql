-- =============================================================================
-- Purpose    : SCD2 이력 스냅샷 — 원천 bronze_crm.TM_CM_DEPT_INFO
-- Target     : snapshot snp_crm_tm_cm_dept_info
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source bronze_crm.TM_CM_DEPT_INFO
-- Issue      : -
-- =============================================================================
{% snapshot snp_crm_tm_cm_dept_info %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='DEPT_ID',
      strategy='check',
      check_cols=['DEPT_NM', 'UPPER_DEPT_ID', 'SORT_ORDR', 'USE_YN', 'ACMSLT_DEPT_YN', 'STATS_DEPT_LVL', 'ACMSLT_UPPER_DEPT_ID'],
      tags=['tier1', 'snapshot']
    )
}}

select
    DEPT_ID,
    DEPT_NM,
    UPPER_DEPT_ID,
    SORT_ORDR,
    USE_YN,
    ACMSLT_DEPT_YN,
    STATS_DEPT_LVL,
    ACMSLT_UPPER_DEPT_ID,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_CM_DEPT_INFO') }}

{% endsnapshot %}
