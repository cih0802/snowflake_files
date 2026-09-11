
      begin;
    merge into "GN_DW"."SNAPSHOT"."SNP_CRM_TM_CM_MBER_DVLP_GOAL" as DBT_INTERNAL_DEST
    using "GN_DW"."SNAPSHOT"."SNP_CRM_TM_CM_MBER_DVLP_GOAL__dbt_tmp" as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.dbt_scd_id = DBT_INTERNAL_DEST.dbt_scd_id

    when matched
     
       and DBT_INTERNAL_DEST.dbt_valid_to is null
     
     and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
        set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to

    when not matched
     and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ("GOAL_SK", "STDYY", "STDR_MT", "MBER_DVLP_DIV_CD", "DEPT_ID", "GOAL_CNT", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")
        values ("GOAL_SK", "STDYY", "STDR_MT", "MBER_DVLP_DIV_CD", "DEPT_ID", "GOAL_CNT", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")

;
    commit;
  