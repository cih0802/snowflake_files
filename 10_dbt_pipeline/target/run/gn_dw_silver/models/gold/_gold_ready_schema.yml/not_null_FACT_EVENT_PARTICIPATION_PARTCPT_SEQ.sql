select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select PARTCPT_SEQ
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
where PARTCPT_SEQ is null



      
    ) dbt_internal_test