select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select EVENT_BK
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
where EVENT_BK is null



      
    ) dbt_internal_test