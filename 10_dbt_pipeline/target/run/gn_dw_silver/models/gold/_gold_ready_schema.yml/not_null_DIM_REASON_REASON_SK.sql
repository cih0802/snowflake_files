select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select REASON_SK
from GN_DW.GOLD.DIM_REASON
where REASON_SK is null



      
    ) dbt_internal_test