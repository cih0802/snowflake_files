select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MK_CMPGN_CD
from GN_DW.SILVER.CRM_MARKETING_CAMPAIGN
where MK_CMPGN_CD is null



      
    ) dbt_internal_test