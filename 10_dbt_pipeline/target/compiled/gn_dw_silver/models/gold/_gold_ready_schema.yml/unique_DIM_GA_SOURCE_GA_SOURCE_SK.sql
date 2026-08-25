
    
    

select
    GA_SOURCE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_GA_SOURCE
where GA_SOURCE_SK is not null
group by GA_SOURCE_SK
having count(*) > 1


