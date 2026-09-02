
    
    

select
    MKTG_CAMPAIGN_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
where MKTG_CAMPAIGN_SK is not null
group by MKTG_CAMPAIGN_SK
having count(*) > 1


