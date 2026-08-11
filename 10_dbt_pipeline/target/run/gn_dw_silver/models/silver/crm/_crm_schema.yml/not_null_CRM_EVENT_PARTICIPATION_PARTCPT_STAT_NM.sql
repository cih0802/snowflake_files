select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select PARTCPT_STAT_NM
from (select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION where PARTCPT_STAT_CD is not null) dbt_subquery
where PARTCPT_STAT_NM is null



      
    ) dbt_internal_test