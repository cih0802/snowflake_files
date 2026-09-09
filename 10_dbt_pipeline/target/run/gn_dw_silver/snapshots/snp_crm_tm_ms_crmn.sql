
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_ms_crmn
         as
        (
    

    select *,
        md5(coalesce(cast(CRMN_CD as varchar ), '')
         || '|' || coalesce(cast(LAST_UPDT_DT as varchar ), '')
        ) as dbt_scd_id,
        LAST_UPDT_DT as dbt_updated_at,
        LAST_UPDT_DT as dbt_valid_from,
        
  
  coalesce(nullif(LAST_UPDT_DT, LAST_UPDT_DT), null)
  as dbt_valid_to
from (
        


select
    CRMN_CD,
    CRMN_DIV_CD,
    CRMN_TIT,
    CRMN_PLACE_NM,
    BRNCH_DEPT_ID,
    ATCHFL_ID,
    SITE_URL,
    CRMN_STRT_DE,
    CRMN_END_DE,
    CRMN_PART_STRT_DE,
    CRMN_PART_END_DE,
    TAT,
    RCRIT_PSNNL_CO,
    RESRCE_SRVC_FG,
    CPR_DIV_CD,
    ENTRPS_CD,
    RM,
    CRMN_CTNT,
    USE_YN,
    PART_USE_YN,
    TMPLAT_ID,
    TMPLAT_TIT,
    TMPLAT_PART_ID,
    TMPLAT_PART_TIT,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from GN_DW.BRONZE_CRM.TM_MS_CRMN

    ) sbq



        );
      
  
  