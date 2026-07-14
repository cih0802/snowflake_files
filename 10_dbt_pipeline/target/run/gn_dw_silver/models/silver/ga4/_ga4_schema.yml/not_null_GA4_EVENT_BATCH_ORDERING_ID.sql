select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BATCH_ORDERING_ID
from GN_DW.SILVER.GA4_EVENT
where BATCH_ORDERING_ID is null



      
    ) dbt_internal_test