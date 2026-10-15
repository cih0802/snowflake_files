select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MONTH_KEY
from GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS
where MONTH_KEY is null



      
    ) dbt_internal_test