select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MKTG_CHANNEL_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where MKTG_CHANNEL IS NOT NULL) dbt_subquery
where MKTG_CHANNEL_NM is null



      
    ) dbt_internal_test