
      
  
    

        create or replace transient table GN_DW.SNAPSHOT.snp_crm_tm_cm_cmpgn_mng
         as
        (
    

    select *,
        md5(coalesce(cast(CMPGN_CD as varchar ), '')
         || '|' || coalesce(cast(LAST_UPDT_DT as varchar ), '')
        ) as dbt_scd_id,
        LAST_UPDT_DT as dbt_updated_at,
        LAST_UPDT_DT as dbt_valid_from,
        
  
  coalesce(nullif(LAST_UPDT_DT, LAST_UPDT_DT), null)
  as dbt_valid_to
from (
        


select
    CMPGN_CD,
    CMPGN_NM,
    UPPER_CMPGN_CD,
    UPPER_CMPGN_YN,
    SPNSR_DIV_CD,
    CPR_DIV_CD,
    CMPGN_TRGET_CD,
    USE_DEPT_CD,
    USE_SCOPE,
    SPNSR_ENTRPRS_ID,
    BRND_ID,
    PR_MTH_CD,
    CMPGN_STRT_DE,
    MBRFEE_BNKB_LIST,
    INICIS_ACNT_NO,
    USE_YN,
    REFER_URL,
    SPNSR_BSNS_ID,
    CMPGN_DC,
    EMRGNCY_AID_BPLC_CD,
    CMPGN_PRPT_YN,
    ATCHFL_ID,
    RM,
    MBER_INFLOW_PATH_CD,
    CMPGN_CTGR_CD,
    CMPGN_TYPE1_BSN,
    CMPGN_TYPE2_BSN,
    MKTG_CMPGN_NM,
    CMMN_BRND,
    MKTG_UTM,
    FRST_RGSTR_ID,
    FRST_REGIST_DT,
    LAST_UPDUSR_ID,
    LAST_UPDT_DT
from GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG

    ) sbq



        );
      
  
  