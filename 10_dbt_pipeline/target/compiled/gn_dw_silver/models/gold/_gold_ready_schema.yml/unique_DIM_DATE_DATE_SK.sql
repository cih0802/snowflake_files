
    
    

select
    DATE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_DATE
where DATE_SK is not null
group by DATE_SK
having count(*) > 1


