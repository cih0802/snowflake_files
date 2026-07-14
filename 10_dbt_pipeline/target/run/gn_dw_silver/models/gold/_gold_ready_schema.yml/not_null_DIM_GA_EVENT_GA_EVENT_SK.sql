select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select GA_EVENT_SK
from GN_DW.GOLD.DIM_GA_EVENT
where GA_EVENT_SK is null



      
    ) dbt_internal_test