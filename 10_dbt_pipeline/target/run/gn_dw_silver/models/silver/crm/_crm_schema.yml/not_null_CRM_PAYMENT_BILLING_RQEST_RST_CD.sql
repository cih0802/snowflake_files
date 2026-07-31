select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select RQEST_RST_CD
from (select * from GN_DW.SILVER.CRM_PAYMENT_BILLING where PAY_STAT_CD = 'F') dbt_subquery
where RQEST_RST_CD is null



      
    ) dbt_internal_test