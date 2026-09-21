
    
    

select
    DEVICE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_DEVICE
where DEVICE_SK is not null
group by DEVICE_SK
having count(*) > 1


