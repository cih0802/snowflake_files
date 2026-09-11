select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select EVENT_KEY
from GN_DW.SILVER.CRM_EVENT
where EVENT_KEY is null



      
    ) dbt_internal_test