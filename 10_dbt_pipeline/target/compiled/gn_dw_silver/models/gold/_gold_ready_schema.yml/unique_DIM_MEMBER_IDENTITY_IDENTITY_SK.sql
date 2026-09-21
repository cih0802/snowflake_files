
    
    

select
    IDENTITY_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_MEMBER_IDENTITY
where IDENTITY_SK is not null
group by IDENTITY_SK
having count(*) > 1


