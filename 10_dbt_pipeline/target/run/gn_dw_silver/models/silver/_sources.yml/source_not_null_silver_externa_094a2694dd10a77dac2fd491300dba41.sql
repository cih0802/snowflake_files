select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select USER_PSEUDO_ID
from (select * from GN_DW.SILVER.BIGQUERY_REFINED_DATA where NOT (EVENT_DATE BETWEEN '20240605' AND '20240610')) dbt_subquery
where USER_PSEUDO_ID is null



      
    ) dbt_internal_test