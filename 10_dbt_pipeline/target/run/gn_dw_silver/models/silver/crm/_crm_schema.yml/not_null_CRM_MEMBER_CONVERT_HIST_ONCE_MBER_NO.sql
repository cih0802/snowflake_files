select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ONCE_MBER_NO
from GN_DW.SILVER.CRM_MEMBER_CONVERT_HIST
where ONCE_MBER_NO is null



      
    ) dbt_internal_test