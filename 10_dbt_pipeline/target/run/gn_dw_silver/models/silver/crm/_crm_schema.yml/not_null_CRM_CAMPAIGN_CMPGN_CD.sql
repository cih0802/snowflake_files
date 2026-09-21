select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CMPGN_CD
from GN_DW.SILVER.CRM_CAMPAIGN
where CMPGN_CD is null



      
    ) dbt_internal_test