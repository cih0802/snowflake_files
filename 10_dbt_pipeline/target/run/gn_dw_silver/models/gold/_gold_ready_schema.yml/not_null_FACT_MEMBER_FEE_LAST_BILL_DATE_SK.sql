select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select LAST_BILL_DATE_SK
from GN_DW.GOLD.FACT_MEMBER_FEE
where LAST_BILL_DATE_SK is null



      
    ) dbt_internal_test