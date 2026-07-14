
    
    

select
    MEMBER_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_MEMBER
where MEMBER_SK is not null
group by MEMBER_SK
having count(*) > 1


