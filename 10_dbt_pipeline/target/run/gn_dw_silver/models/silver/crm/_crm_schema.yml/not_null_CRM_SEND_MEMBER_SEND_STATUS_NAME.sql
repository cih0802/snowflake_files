select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SEND_STATUS_NAME
from (select * from GN_DW.SILVER.CRM_SEND_MEMBER where SEND_CHANNEL = 'MSG_AT' and SNDNG_RST_CD is not null) dbt_subquery
where SEND_STATUS_NAME is null



      
    ) dbt_internal_test