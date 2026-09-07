select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SERVICE_SK
from GN_DW.GOLD.FACT_SERVICE_EVENT
where SERVICE_SK is null



      
    ) dbt_internal_test