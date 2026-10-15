select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select PAYMENT_SK
from GN_DW.GOLD.FACT_MEMBER_FEE
where PAYMENT_SK is null



      
    ) dbt_internal_test