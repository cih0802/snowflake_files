select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SEND_RESULT_NAME
from (select * from GN_DW.SILVER.CRM_SEND_MEMBER where SEND_RESULT_CD is not null) dbt_subquery
where SEND_RESULT_NAME is null



      
    ) dbt_internal_test