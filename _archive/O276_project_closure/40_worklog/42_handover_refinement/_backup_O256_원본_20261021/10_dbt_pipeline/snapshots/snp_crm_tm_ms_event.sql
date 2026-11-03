{% snapshot snp_crm_tm_ms_event %}
{{
    config(
      target_database='GN_DW',
      target_schema='SNAPSHOT',
      unique_key='EVENT_CD',
      strategy='timestamp',
      updated_at='LAST_UPDT_DT',
      tags=['tier2', 'snapshot']
    )
}}

select
    EVENT_CD,
    EVENT_DIV_CD,
    EVENT_NM,
    STRT_DATE,
    END_DATE,
    PRZWIN_PSNNL_CO,
    PRZWIN_GFT_SNDNG_DE,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from {{ source('bronze_crm', 'TM_MS_EVENT') }}

{% endsnapshot %}
