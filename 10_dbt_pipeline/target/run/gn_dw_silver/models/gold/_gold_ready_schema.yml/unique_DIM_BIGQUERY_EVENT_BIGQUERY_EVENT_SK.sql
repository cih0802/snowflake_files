select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    BIGQUERY_EVENT_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_BIGQUERY_EVENT
where BIGQUERY_EVENT_SK is not null
group by BIGQUERY_EVENT_SK
having count(*) > 1



      
    ) dbt_internal_test