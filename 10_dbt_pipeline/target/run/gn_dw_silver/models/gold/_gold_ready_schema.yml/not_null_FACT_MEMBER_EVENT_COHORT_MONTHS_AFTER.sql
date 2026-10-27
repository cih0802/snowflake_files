select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MONTHS_AFTER
from GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT
where MONTHS_AFTER is null



      
    ) dbt_internal_test