select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MKTG_CAMPAIGN_BK
from GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
where MKTG_CAMPAIGN_BK is null



      
    ) dbt_internal_test