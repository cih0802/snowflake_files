select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select DEV_CNT_RAW
from GN_DW.GOLD.FACT_MEMBER_EVENT
where DEV_CNT_RAW is null



      
    ) dbt_internal_test