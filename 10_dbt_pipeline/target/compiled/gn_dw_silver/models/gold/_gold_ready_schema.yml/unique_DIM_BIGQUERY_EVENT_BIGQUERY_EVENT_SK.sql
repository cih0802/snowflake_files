
    
    

select
    BIGQUERY_EVENT_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_BIGQUERY_EVENT
where BIGQUERY_EVENT_SK is not null
group by BIGQUERY_EVENT_SK
having count(*) > 1


