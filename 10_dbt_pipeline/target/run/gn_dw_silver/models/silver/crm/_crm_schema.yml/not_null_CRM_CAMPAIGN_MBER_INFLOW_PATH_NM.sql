select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MBER_INFLOW_PATH_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where MBER_INFLOW_PATH_CD IS NOT NULL) dbt_subquery
where MBER_INFLOW_PATH_NM is null



      
    ) dbt_internal_test