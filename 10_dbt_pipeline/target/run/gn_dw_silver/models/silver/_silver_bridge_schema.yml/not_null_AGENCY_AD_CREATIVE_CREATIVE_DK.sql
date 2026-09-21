select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CREATIVE_DK
from GN_DW.SILVER.AGENCY_AD_CREATIVE
where CREATIVE_DK is null



      
    ) dbt_internal_test