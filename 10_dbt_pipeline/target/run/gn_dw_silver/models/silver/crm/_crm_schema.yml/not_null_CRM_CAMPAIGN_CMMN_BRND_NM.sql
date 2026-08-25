select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CMMN_BRND_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMMN_BRND IS NOT NULL) dbt_subquery
where CMMN_BRND_NM is null



      
    ) dbt_internal_test