select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select IS_MULTI_CAMPAIGN
from GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ
where IS_MULTI_CAMPAIGN is null



      
    ) dbt_internal_test