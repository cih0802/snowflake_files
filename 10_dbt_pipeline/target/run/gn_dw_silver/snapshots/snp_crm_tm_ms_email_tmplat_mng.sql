
      begin;
    merge into "GN_DW"."SNAPSHOT"."SNP_CRM_TM_MS_EMAIL_TMPLAT_MNG" as DBT_INTERNAL_DEST
    using "GN_DW"."SNAPSHOT"."SNP_CRM_TM_MS_EMAIL_TMPLAT_MNG__dbt_tmp" as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.dbt_scd_id = DBT_INTERNAL_DEST.dbt_scd_id

    when matched
     
       and DBT_INTERNAL_DEST.dbt_valid_to is null
     
     and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
        set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to

    when not matched
     and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ("TMPLAT_KEY", "CPR_DIV_CD", "SNDNG_CD_ID", "SNDNG_DTL_CD_ID", "ATMC_YN", "TIT", "EMAIL_CTNT", "WRITNG_DEPT_ID", "WRITNG_DEPT_NM", "CHRG_DEPT_ID", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")
        values ("TMPLAT_KEY", "CPR_DIV_CD", "SNDNG_CD_ID", "SNDNG_DTL_CD_ID", "ATMC_YN", "TIT", "EMAIL_CTNT", "WRITNG_DEPT_ID", "WRITNG_DEPT_NM", "CHRG_DEPT_ID", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")

;
    commit;
  