select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select DEPT_ID
from GN_DW.SILVER.CRM_ORG
where DEPT_ID is null



      
    ) dbt_internal_test