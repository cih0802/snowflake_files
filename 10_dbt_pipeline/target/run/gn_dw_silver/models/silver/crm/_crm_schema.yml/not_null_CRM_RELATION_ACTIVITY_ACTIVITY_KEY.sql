select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ACTIVITY_KEY
from GN_DW.SILVER.CRM_RELATION_ACTIVITY
where ACTIVITY_KEY is null



      
    ) dbt_internal_test