select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select AD_PERF_DK
from GN_DW.GOLD.FACT_AD_BROADCAST_CASE
where AD_PERF_DK is null



      
    ) dbt_internal_test