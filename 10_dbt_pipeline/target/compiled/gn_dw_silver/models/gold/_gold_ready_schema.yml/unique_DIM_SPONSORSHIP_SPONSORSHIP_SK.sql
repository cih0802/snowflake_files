
    
    

select
    SPONSORSHIP_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_SPONSORSHIP
where SPONSORSHIP_SK is not null
group by SPONSORSHIP_SK
having count(*) > 1


