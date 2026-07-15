select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CAMPAIGN_SK
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
where CAMPAIGN_SK is null



      
    ) dbt_internal_test