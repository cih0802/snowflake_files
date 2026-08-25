select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select PAGE_PATH
from GN_DW.GOLD.FACT_GA_BEHAVIOR
where PAGE_PATH is null



      
    ) dbt_internal_test