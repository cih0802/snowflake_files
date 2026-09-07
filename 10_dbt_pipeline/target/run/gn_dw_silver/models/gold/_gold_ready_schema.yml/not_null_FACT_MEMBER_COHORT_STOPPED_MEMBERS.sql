select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select STOPPED_MEMBERS
from GN_DW.GOLD.FACT_MEMBER_COHORT
where STOPPED_MEMBERS is null



      
    ) dbt_internal_test