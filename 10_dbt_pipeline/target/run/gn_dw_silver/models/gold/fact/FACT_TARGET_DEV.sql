begin;
    insert into GN_DW.GOLD.FACT_TARGET_DEV ("MONTH_KEY", "ORG_SK", "DEV_TYPE", "GOAL_CNT", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID")
    (
        select "MONTH_KEY", "ORG_SK", "DEV_TYPE", "GOAL_CNT", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"
        from GN_DW.GOLD.FACT_TARGET_DEV__dbt_tmp
    )

;
    commit;