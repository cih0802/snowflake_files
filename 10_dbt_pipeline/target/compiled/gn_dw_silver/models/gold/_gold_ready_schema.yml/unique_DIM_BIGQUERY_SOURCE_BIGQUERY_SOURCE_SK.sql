
    
    

select
    BIGQUERY_SOURCE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_BIGQUERY_SOURCE
where BIGQUERY_SOURCE_SK is not null
group by BIGQUERY_SOURCE_SK
having count(*) > 1


