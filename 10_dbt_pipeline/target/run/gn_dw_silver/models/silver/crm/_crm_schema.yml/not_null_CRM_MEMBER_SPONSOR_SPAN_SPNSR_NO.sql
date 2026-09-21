select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SPNSR_NO
from GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN
where SPNSR_NO is null



      
    ) dbt_internal_test