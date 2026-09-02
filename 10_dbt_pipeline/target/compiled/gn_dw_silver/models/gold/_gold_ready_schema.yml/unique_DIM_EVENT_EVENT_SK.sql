
    
    

select
    EVENT_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_EVENT
where EVENT_SK is not null
group by EVENT_SK
having count(*) > 1


