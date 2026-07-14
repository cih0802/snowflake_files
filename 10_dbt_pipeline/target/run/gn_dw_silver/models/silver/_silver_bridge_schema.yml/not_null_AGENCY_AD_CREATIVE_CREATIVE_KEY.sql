select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CREATIVE_KEY
from GN_DW.SILVER.AGENCY_AD_CREATIVE
where CREATIVE_KEY is null



      
    ) dbt_internal_test