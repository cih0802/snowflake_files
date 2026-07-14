select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select GA_SOURCE_SK
from GN_DW.GOLD.DIM_GA_SOURCE
where GA_SOURCE_SK is null



      
    ) dbt_internal_test