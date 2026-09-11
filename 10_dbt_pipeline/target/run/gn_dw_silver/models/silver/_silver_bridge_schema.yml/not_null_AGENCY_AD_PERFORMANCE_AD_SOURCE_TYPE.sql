select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select AD_SOURCE_TYPE
from GN_DW.SILVER.AGENCY_AD_PERFORMANCE
where AD_SOURCE_TYPE is null



      
    ) dbt_internal_test