select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SEND_TYPE_SK
from GN_DW.GOLD.FACT_SERVICE_EVENT
where SEND_TYPE_SK is null



      
    ) dbt_internal_test