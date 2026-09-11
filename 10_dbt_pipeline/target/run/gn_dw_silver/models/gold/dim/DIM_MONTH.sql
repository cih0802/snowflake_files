begin;
    insert into GN_DW.GOLD.DIM_MONTH ("MONTH_KEY", "YEAR", "MONTH", "QUARTER", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID")
    (
        select "MONTH_KEY", "YEAR", "MONTH", "QUARTER", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"
        from GN_DW.GOLD.DIM_MONTH__dbt_tmp
    )

;
    commit;