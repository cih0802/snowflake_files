select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ROW_KIND
from GN_DW.GOLD.FACT_AD_INFLOW_ALLOC
where ROW_KIND is null



      
    ) dbt_internal_test