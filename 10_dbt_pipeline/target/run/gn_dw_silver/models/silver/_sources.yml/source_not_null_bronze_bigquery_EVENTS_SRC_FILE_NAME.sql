select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SRC_FILE_NAME
from GN_DW.BRONZE_BIGQUERY.EVENTS
where SRC_FILE_NAME is null



      
    ) dbt_internal_test