select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select DEVICE_TYPE
from GN_DW.SILVER.GA4_DEVICE
where DEVICE_TYPE is null



      
    ) dbt_internal_test