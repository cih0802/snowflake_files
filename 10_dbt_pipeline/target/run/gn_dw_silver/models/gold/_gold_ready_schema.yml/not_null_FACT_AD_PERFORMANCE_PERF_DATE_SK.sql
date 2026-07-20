select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select PERF_DATE_SK
from GN_DW.GOLD.FACT_AD_PERFORMANCE
where PERF_DATE_SK is null



      
    ) dbt_internal_test