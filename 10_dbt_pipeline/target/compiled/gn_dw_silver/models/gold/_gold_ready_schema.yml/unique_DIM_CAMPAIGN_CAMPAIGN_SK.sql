
    
    

select
    CAMPAIGN_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_CAMPAIGN
where CAMPAIGN_SK is not null
group by CAMPAIGN_SK
having count(*) > 1


