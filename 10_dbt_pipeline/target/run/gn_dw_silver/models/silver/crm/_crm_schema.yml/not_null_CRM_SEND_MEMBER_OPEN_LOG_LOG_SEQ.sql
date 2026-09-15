select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select LOG_SEQ
from GN_DW.SILVER.CRM_SEND_MEMBER_OPEN_LOG
where LOG_SEQ is null



      
    ) dbt_internal_test