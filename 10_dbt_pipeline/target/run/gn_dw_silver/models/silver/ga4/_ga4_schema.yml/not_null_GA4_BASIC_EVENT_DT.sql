select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select EVENT_DT
from GN_DW.SILVER.GA4_BASIC
where EVENT_DT is null



      
    ) dbt_internal_test