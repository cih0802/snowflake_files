select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SPNSR_BSNS_ID
from GN_DW.SILVER.CRM_MEMBER_SPONSOR_BIZ
where SPNSR_BSNS_ID is null



      
    ) dbt_internal_test