
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_cm_dept_info
         as
        (
    

    select *,
        md5(coalesce(cast(DEPT_ID as varchar ), '')
         || '|' || coalesce(cast(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as varchar ), '')
        ) as dbt_scd_id,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_updated_at,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_valid_from,
        
  
  coalesce(nullif(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())), to_timestamp_ntz(convert_timezone('UTC', current_timestamp()))), null)
  as dbt_valid_to
from (
        


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
from GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO

    ) sbq



        );
      
  
  