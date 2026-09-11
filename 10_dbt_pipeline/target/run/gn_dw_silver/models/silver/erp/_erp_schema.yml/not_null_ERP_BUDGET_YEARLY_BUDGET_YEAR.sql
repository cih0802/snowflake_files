select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BUDGET_YEAR
from GN_DW.SILVER.ERP_BUDGET_YEARLY
where BUDGET_YEAR is null



      
    ) dbt_internal_test