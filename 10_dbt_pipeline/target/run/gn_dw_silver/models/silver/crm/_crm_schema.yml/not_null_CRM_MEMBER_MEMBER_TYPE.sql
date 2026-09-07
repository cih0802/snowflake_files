select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MEMBER_TYPE
from GN_DW.SILVER.CRM_MEMBER
where MEMBER_TYPE is null



      
    ) dbt_internal_test