select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select CASE_SEQ
from GN_DW.GOLD.FACT_AD_BROADCAST_CASE
where CASE_SEQ is null



      
    ) dbt_internal_test