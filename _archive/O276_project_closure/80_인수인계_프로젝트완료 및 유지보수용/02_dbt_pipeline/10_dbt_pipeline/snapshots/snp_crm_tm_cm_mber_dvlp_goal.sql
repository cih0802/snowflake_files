-- =============================================================================
-- Purpose    : SCD2 이력 스냅샷 — 원천 bronze_crm.TM_CM_MBER_DVLP_GOAL
-- Target     : snapshot snp_crm_tm_cm_mber_dvlp_goal
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source bronze_crm.TM_CM_MBER_DVLP_GOAL
-- Issue      : -
-- =============================================================================
{% snapshot snp_crm_tm_cm_mber_dvlp_goal %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='GOAL_SK',
      strategy='timestamp',
      updated_at='LAST_UPDT_DT',
      tags=['tier1', 'snapshot']
    )
}}

select
    MD5(COALESCE(DEPT_ID,'') || '|' || COALESCE(STDYY,'') || '|' || COALESCE(STDR_MT,'') || '|' || COALESCE(MBER_DVLP_DIV_CD,'')) as GOAL_SK,
    STDYY,
    STDR_MT,
    MBER_DVLP_DIV_CD,
    DEPT_ID,
    GOAL_CNT,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_CM_MBER_DVLP_GOAL') }}

{% endsnapshot %}
