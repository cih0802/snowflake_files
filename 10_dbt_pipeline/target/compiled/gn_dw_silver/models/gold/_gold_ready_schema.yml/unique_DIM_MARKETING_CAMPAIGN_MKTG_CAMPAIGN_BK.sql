
    
    

select
    MKTG_CAMPAIGN_BK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
where MKTG_CAMPAIGN_BK is not null
group by MKTG_CAMPAIGN_BK
having count(*) > 1


