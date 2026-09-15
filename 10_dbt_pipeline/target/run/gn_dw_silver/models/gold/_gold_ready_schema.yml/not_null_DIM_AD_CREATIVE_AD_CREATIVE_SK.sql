select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select AD_CREATIVE_SK
from GN_DW.GOLD.DIM_AD_CREATIVE
where AD_CREATIVE_SK is null



      
    ) dbt_internal_test