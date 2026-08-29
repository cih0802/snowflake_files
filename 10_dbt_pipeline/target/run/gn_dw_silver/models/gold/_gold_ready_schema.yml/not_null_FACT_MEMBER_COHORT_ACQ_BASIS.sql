select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ACQ_BASIS
from GN_DW.GOLD.FACT_MEMBER_COHORT
where ACQ_BASIS is null



      
    ) dbt_internal_test