select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select AD_PERF_DK
from GN_DW.SILVER.AGENCY_AD_ROW_REBRDC
where AD_PERF_DK is null



      
    ) dbt_internal_test