select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MBER_NO
from GN_DW.SILVER.CRM_SEND_MEMBER
where MBER_NO is null



      
    ) dbt_internal_test