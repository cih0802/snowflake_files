
      begin;
    merge into "GN_DW"."SNAPSHOT"."SNP_CRM_TM_MS_EVENT" as DBT_INTERNAL_DEST
    using "GN_DW"."SNAPSHOT"."SNP_CRM_TM_MS_EVENT__dbt_tmp" as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.dbt_scd_id = DBT_INTERNAL_DEST.dbt_scd_id

    when matched
     
       and DBT_INTERNAL_DEST.dbt_valid_to is null
     
     and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
        set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to

    when not matched
     and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ("EVENT_CD", "EVENT_DIV_CD", "EVENT_NM", "STRT_DATE", "END_DATE", "PRZWIN_PSNNL_CO", "PRZWIN_GFT_SNDNG_DE", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")
        values ("EVENT_CD", "EVENT_DIV_CD", "EVENT_NM", "STRT_DATE", "END_DATE", "PRZWIN_PSNNL_CO", "PRZWIN_GFT_SNDNG_DE", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")

;
    commit;
  