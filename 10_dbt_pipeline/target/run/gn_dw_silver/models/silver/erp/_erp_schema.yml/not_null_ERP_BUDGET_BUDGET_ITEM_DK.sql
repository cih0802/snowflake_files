select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BUDGET_ITEM_DK
from GN_DW.SILVER.ERP_BUDGET
where BUDGET_ITEM_DK is null



      
    ) dbt_internal_test