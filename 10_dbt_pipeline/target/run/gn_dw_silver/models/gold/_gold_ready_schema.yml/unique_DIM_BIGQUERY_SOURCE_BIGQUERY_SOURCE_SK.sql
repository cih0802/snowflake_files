select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    BIGQUERY_SOURCE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_BIGQUERY_SOURCE
where BIGQUERY_SOURCE_SK is not null
group by BIGQUERY_SOURCE_SK
having count(*) > 1



      
    ) dbt_internal_test