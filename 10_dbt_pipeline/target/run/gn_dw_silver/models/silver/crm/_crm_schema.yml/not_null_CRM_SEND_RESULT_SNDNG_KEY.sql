select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SNDNG_KEY
from GN_DW.SILVER.CRM_SEND_RESULT
where SNDNG_KEY is null



      
    ) dbt_internal_test