
      begin;
    merge into "GN_DW"."SNAPSHOT"."SNP_CRM_TM_CM_BRND_MNG" as DBT_INTERNAL_DEST
    using "GN_DW"."SNAPSHOT"."SNP_CRM_TM_CM_BRND_MNG__dbt_tmp" as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.dbt_scd_id = DBT_INTERNAL_DEST.dbt_scd_id

    when matched
     
       and DBT_INTERNAL_DEST.dbt_valid_to is null
     
     and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
        set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to

    when not matched
     and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ("BRND_ID", "BRND_NM", "USE_DEPT_CD", "USE_YN", "PR_MTH_LIST", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")
        values ("BRND_ID", "BRND_NM", "USE_DEPT_CD", "USE_YN", "PR_MTH_LIST", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")

;
    commit;
  