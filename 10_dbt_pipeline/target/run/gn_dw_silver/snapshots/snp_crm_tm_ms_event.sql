
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_ms_event
         as
        (
    

    select *,
        md5(coalesce(cast(EVENT_CD as varchar ), '')
         || '|' || coalesce(cast(LAST_UPDT_DT as varchar ), '')
        ) as dbt_scd_id,
        LAST_UPDT_DT as dbt_updated_at,
        LAST_UPDT_DT as dbt_valid_from,
        
  
  coalesce(nullif(LAST_UPDT_DT, LAST_UPDT_DT), null)
  as dbt_valid_to
from (
        


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
from GN_DW.BRONZE_CRM.TM_MS_EVENT

    ) sbq



        );
      
  
  