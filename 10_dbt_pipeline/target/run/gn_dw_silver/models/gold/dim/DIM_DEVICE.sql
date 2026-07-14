-- back compat for old kwarg name
  
  begin;
    
        
            
	    
	    
            
        
    

    

    merge into GN_DW.GOLD.DIM_DEVICE as DBT_INTERNAL_DEST
        using GN_DW.GOLD.DIM_DEVICE__dbt_tmp as DBT_INTERNAL_SOURCE
        on ((DBT_INTERNAL_SOURCE.DEVICE_SK = DBT_INTERNAL_DEST.DEVICE_SK))

    
    when matched then update set
        "DEVICE_SK" = DBT_INTERNAL_SOURCE."DEVICE_SK","DEVICE_TYPE" = DBT_INTERNAL_SOURCE."DEVICE_TYPE","DW_SOURCE_SYSTEM" = DBT_INTERNAL_SOURCE."DW_SOURCE_SYSTEM","DW_LOAD_TS" = DBT_INTERNAL_SOURCE."DW_LOAD_TS","DW_UPDATE_TS" = DBT_INTERNAL_SOURCE."DW_UPDATE_TS","DW_BATCH_ID" = DBT_INTERNAL_SOURCE."DW_BATCH_ID"
    

    when not matched then insert
        ("DEVICE_SK", "DEVICE_TYPE", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID")
    values
        ("DEVICE_SK", "DEVICE_TYPE", "DW_SOURCE_SYSTEM", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID")

;
    commit;