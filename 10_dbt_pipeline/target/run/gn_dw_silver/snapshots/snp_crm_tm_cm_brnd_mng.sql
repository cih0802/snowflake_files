
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_cm_brnd_mng
         as
        (
    

    select *,
        md5(coalesce(cast(BRND_ID as varchar ), '')
         || '|' || coalesce(cast(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as varchar ), '')
        ) as dbt_scd_id,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_updated_at,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_valid_from,
        
  
  coalesce(nullif(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())), to_timestamp_ntz(convert_timezone('UTC', current_timestamp()))), null)
  as dbt_valid_to
from (
        


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
from GN_DW.BRONZE_CRM.TM_CM_BRND_MNG

    ) sbq



        );
      
  
  