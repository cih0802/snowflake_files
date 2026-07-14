select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select EVENT_TIMESTAMP
from GN_DW.SILVER.GA4_EVENT
where EVENT_TIMESTAMP is null



      
    ) dbt_internal_test