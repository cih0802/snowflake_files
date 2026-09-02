select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ACTIVITY_TYPE
from GN_DW.SILVER.CRM_RELATION_ACTIVITY
where ACTIVITY_TYPE is null



      
    ) dbt_internal_test