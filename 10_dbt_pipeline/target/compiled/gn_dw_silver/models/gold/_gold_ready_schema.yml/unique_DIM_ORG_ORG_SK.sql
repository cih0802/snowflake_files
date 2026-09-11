
    
    

select
    ORG_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_ORG
where ORG_SK is not null
group by ORG_SK
having count(*) > 1


