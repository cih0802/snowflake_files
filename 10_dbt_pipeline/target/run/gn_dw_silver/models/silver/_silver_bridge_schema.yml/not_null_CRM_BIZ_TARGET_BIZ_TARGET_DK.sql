select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BIZ_TARGET_DK
from GN_DW.SILVER.CRM_BIZ_TARGET
where BIZ_TARGET_DK is null



      
    ) dbt_internal_test