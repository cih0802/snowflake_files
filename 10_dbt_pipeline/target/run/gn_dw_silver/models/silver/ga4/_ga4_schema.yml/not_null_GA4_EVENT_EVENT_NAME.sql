select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select EVENT_NAME
from GN_DW.SILVER.GA4_EVENT
where EVENT_NAME is null



      
    ) dbt_internal_test