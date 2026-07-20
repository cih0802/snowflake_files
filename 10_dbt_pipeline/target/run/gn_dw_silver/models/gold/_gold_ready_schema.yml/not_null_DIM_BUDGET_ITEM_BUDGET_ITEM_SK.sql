select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BUDGET_ITEM_SK
from GN_DW.GOLD.DIM_BUDGET_ITEM
where BUDGET_ITEM_SK is null



      
    ) dbt_internal_test