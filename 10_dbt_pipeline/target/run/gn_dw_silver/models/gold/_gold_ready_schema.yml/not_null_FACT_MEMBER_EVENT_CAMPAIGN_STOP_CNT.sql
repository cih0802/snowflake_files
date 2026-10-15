select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CAMPAIGN_STOP_CNT
from GN_DW.GOLD.FACT_MEMBER_EVENT
where CAMPAIGN_STOP_CNT is null



      
    ) dbt_internal_test