begin;
    insert into GN_DW.SILVER.CRM_CODE ("CD_ID", "DTL_CD_ID", "DTL_CD_NM", "UPPER_CD_ID", "SORT_ORDR", "USE_YN", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID")
    (
        select "CD_ID", "DTL_CD_ID", "DTL_CD_NM", "UPPER_CD_ID", "SORT_ORDR", "USE_YN", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"
        from GN_DW.SILVER.CRM_CODE__dbt_tmp
    )

;
    commit;