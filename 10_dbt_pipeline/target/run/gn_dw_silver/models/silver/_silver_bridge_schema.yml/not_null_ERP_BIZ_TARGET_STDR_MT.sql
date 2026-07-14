select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select STDR_MT
from GN_DW.SILVER.ERP_BIZ_TARGET
where STDR_MT is null



      
    ) dbt_internal_test