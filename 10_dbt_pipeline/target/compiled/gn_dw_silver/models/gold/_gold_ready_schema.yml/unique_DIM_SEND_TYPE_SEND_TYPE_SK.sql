
    
    

select
    SEND_TYPE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_SEND_TYPE
where SEND_TYPE_SK is not null
group by SEND_TYPE_SK
having count(*) > 1


