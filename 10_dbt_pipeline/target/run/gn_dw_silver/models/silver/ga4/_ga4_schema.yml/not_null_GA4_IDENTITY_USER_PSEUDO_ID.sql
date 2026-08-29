select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select USER_PSEUDO_ID
from GN_DW.SILVER.GA4_IDENTITY
where USER_PSEUDO_ID is null



      
    ) dbt_internal_test