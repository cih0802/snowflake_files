
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_cm_mber_dvlp_goal
         as
        (
    

    select *,
        md5(coalesce(cast(GOAL_SK as varchar ), '')
         || '|' || coalesce(cast(LAST_UPDT_DT as varchar ), '')
        ) as dbt_scd_id,
        LAST_UPDT_DT as dbt_updated_at,
        LAST_UPDT_DT as dbt_valid_from,
        
  
  coalesce(nullif(LAST_UPDT_DT, LAST_UPDT_DT), null)
  as dbt_valid_to
from (
        


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
from GN_DW.BRONZE_CRM.TM_CM_MBER_DVLP_GOAL

    ) sbq



        );
      
  
  