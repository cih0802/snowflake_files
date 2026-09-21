select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MONTH_NO
from GN_DW.SILVER.ERP_BUDGET
where MONTH_NO is null



      
    ) dbt_internal_test