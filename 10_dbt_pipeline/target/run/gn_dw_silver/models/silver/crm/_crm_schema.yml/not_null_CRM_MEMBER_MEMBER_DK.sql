select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MEMBER_DK
from GN_DW.SILVER.CRM_MEMBER
where MEMBER_DK is null



      
    ) dbt_internal_test