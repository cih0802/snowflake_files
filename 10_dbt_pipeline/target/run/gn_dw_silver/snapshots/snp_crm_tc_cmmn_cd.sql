
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tc_cmmn_cd
         as
        (
    

    select *,
        md5(coalesce(cast(CD_ID as varchar ), '')
         || '|' || coalesce(cast(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as varchar ), '')
        ) as dbt_scd_id,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_updated_at,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_valid_from,
        
  
  coalesce(nullif(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())), to_timestamp_ntz(convert_timezone('UTC', current_timestamp()))), null)
  as dbt_valid_to
from (
        


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
from GN_DW.BRONZE_CRM.TC_CMMN_CD

    ) sbq



        );
      
  
  