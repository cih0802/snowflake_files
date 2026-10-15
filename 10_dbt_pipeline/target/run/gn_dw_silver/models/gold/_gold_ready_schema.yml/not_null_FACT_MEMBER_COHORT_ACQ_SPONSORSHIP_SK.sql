select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ACQ_SPONSORSHIP_SK
from GN_DW.GOLD.FACT_MEMBER_COHORT
where ACQ_SPONSORSHIP_SK is null



      
    ) dbt_internal_test