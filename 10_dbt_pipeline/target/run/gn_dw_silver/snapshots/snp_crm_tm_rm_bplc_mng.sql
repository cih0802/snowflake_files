
      begin;
    merge into "GN_DW"."SNAPSHOT"."SNP_CRM_TM_RM_BPLC_MNG" as DBT_INTERNAL_DEST
    using "GN_DW"."SNAPSHOT"."SNP_CRM_TM_RM_BPLC_MNG__dbt_tmp" as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.dbt_scd_id = DBT_INTERNAL_DEST.dbt_scd_id

    when matched
     
       and DBT_INTERNAL_DEST.dbt_valid_to is null
     
     and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
        set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to

    when not matched
     and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ("BPLC_CD", "NATION_CD", "BPLC_KORNM", "BPLC_ENGNM", "BSNS_STRT_DE", "BSNS_END_DE", "RELATNSP_BSNS_YN", "RELATNSP_BSNS_DSCNTC_DE", "GFTMNEY_PSBL_YN", "LETTER_PSBL_YN", "BPLC_DC", "WTWK_FROM_DSTNC", "CNCSN_RSN", "BPLC_MTCHG_MNG_YN", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")
        values ("BPLC_CD", "NATION_CD", "BPLC_KORNM", "BPLC_ENGNM", "BSNS_STRT_DE", "BSNS_END_DE", "RELATNSP_BSNS_YN", "RELATNSP_BSNS_DSCNTC_DE", "GFTMNEY_PSBL_YN", "LETTER_PSBL_YN", "BPLC_DC", "WTWK_FROM_DSTNC", "CNCSN_RSN", "BPLC_MTCHG_MNG_YN", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")

;
    commit;
  