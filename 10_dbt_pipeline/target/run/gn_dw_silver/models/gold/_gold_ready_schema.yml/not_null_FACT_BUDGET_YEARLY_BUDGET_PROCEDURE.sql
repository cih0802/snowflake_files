select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BUDGET_PROCEDURE
from GN_DW.GOLD.FACT_BUDGET_YEARLY
where BUDGET_PROCEDURE is null



      
    ) dbt_internal_test