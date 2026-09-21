begin;
    insert into GN_DW.SILVER.CRM_MKTNG_CODE ("CD_ID", "DTL_CD_ID", "CD_NM", "DTL_CD_NM", "SORT_ORDR", "USE_YN", "RM", "CD_ATRB1", "CD_ATRB2", "CD_ATRB3", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID")
    (
        select "CD_ID", "DTL_CD_ID", "CD_NM", "DTL_CD_NM", "SORT_ORDR", "USE_YN", "RM", "CD_ATRB1", "CD_ATRB2", "CD_ATRB3", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"
        from GN_DW.SILVER.CRM_MKTNG_CODE__dbt_tmp
    )

;
    commit;