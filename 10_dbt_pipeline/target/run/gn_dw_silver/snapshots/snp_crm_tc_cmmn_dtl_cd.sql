
      begin;
    merge into "GN_DW"."SNAPSHOT"."SNP_CRM_TC_CMMN_DTL_CD" as DBT_INTERNAL_DEST
    using "GN_DW"."SNAPSHOT"."SNP_CRM_TC_CMMN_DTL_CD__dbt_tmp" as DBT_INTERNAL_SOURCE
    on DBT_INTERNAL_SOURCE.dbt_scd_id = DBT_INTERNAL_DEST.dbt_scd_id

    when matched
     
       and DBT_INTERNAL_DEST.dbt_valid_to is null
     
     and DBT_INTERNAL_SOURCE.dbt_change_type in ('update', 'delete')
        then update
        set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to

    when not matched
     and DBT_INTERNAL_SOURCE.dbt_change_type = 'insert'
        then insert ("CMMN_DTL_CD_SK", "CD_ID", "DTL_CD_ID", "DTL_CD_NM", "DTL_CD_DC", "SORT_ORDR", "RM", "USE_YN", "CD_ATRB1", "CD_ATRB2", "CD_ATRB3", "UPPER_CD_ID", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")
        values ("CMMN_DTL_CD_SK", "CD_ID", "DTL_CD_ID", "DTL_CD_NM", "DTL_CD_DC", "SORT_ORDR", "RM", "USE_YN", "CD_ATRB1", "CD_ATRB2", "CD_ATRB3", "UPPER_CD_ID", "FRST_RGSTR_ID", "FRST_REGIST_DT", "LAST_UPDUSR_ID", "LAST_UPDT_DT", "DBT_UPDATED_AT", "DBT_VALID_FROM", "DBT_VALID_TO", "DBT_SCD_ID")

;
    commit;
  