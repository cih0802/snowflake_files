select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MKTG_UTM_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where MKTG_UTM IS NOT NULL) dbt_subquery
where MKTG_UTM_NM is null



      
    ) dbt_internal_test