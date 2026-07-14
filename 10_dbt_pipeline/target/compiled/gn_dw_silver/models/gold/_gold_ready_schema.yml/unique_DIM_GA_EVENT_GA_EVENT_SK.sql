
    
    

select
    GA_EVENT_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_GA_EVENT
where GA_EVENT_SK is not null
group by GA_EVENT_SK
having count(*) > 1


