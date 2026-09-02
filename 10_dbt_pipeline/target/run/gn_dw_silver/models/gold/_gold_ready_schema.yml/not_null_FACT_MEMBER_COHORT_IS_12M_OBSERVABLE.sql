select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select IS_12M_OBSERVABLE
from GN_DW.GOLD.FACT_MEMBER_COHORT
where IS_12M_OBSERVABLE is null



      
    ) dbt_internal_test