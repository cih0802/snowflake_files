select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select RELATNSP_KEY
from GN_DW.SILVER.CRM_RELATION_ACTIVITY
where RELATNSP_KEY is null



      
    ) dbt_internal_test