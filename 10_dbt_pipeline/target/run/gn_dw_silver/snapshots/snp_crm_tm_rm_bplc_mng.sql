
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_rm_bplc_mng
         as
        (
    

    select *,
        md5(coalesce(cast(BPLC_CD as varchar ), '')
         || '|' || coalesce(cast(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as varchar ), '')
        ) as dbt_scd_id,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_updated_at,
        to_timestamp_ntz(convert_timezone('UTC', current_timestamp())) as dbt_valid_from,
        
  
  coalesce(nullif(to_timestamp_ntz(convert_timezone('UTC', current_timestamp())), to_timestamp_ntz(convert_timezone('UTC', current_timestamp()))), null)
  as dbt_valid_to
from (
        


select
    BPLC_CD,
    NATION_CD,
    BPLC_KORNM,
    BPLC_ENGNM,
    BSNS_STRT_DE,
    BSNS_END_DE,
    RELATNSP_BSNS_YN,
    RELATNSP_BSNS_DSCNTC_DE,
    GFTMNEY_PSBL_YN,
    LETTER_PSBL_YN,
    BPLC_DC,
    WTWK_FROM_DSTNC,
    CNCSN_RSN,
    BPLC_MTCHG_MNG_YN,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from GN_DW.BRONZE_CRM.TM_RM_BPLC_MNG

    ) sbq



        );
      
  
  