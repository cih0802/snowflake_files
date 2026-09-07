select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MKTG_CAMPAIGN_SK
from GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
where MKTG_CAMPAIGN_SK is null



      
    ) dbt_internal_test