select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SPNSR_DIV_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where SPNSR_DIV_CD IS NOT NULL) dbt_subquery
where SPNSR_DIV_NM is null



      
    ) dbt_internal_test