select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BUDGET_PROCEDURE
from GN_DW.SILVER.ERP_BUDGET
where BUDGET_PROCEDURE is null



      
    ) dbt_internal_test