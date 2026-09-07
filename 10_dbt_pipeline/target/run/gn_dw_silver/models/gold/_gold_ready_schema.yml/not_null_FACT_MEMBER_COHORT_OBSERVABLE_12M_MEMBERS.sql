select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select OBSERVABLE_12M_MEMBERS
from GN_DW.GOLD.FACT_MEMBER_COHORT
where OBSERVABLE_12M_MEMBERS is null



      
    ) dbt_internal_test