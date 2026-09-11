
    
    

select
    REASON_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_REASON
where REASON_SK is not null
group by REASON_SK
having count(*) > 1


