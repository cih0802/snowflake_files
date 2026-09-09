
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_ms_email_tmplat_mng
         as
        (
    

    select *,
        md5(coalesce(cast(TMPLAT_KEY as varchar ), '')
         || '|' || coalesce(cast(LAST_UPDT_DT as varchar ), '')
        ) as dbt_scd_id,
        LAST_UPDT_DT as dbt_updated_at,
        LAST_UPDT_DT as dbt_valid_from,
        
  
  coalesce(nullif(LAST_UPDT_DT, LAST_UPDT_DT), null)
  as dbt_valid_to
from (
        


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
from GN_DW.BRONZE_CRM.TM_MS_EMAIL_TMPLAT_MNG

    ) sbq



        );
      
  
  