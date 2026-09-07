select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SPNSR_BSNS_NO
from GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ
where SPNSR_BSNS_NO is null



      
    ) dbt_internal_test