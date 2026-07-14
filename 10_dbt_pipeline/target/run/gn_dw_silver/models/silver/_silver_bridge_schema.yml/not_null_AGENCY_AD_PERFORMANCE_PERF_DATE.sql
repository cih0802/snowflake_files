select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select PERF_DATE
from GN_DW.SILVER.AGENCY_AD_PERFORMANCE
where PERF_DATE is null



      
    ) dbt_internal_test