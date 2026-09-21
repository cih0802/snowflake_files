select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select BIGQUERY_EVENT_SK
from GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR
where BIGQUERY_EVENT_SK is null



      
    ) dbt_internal_test