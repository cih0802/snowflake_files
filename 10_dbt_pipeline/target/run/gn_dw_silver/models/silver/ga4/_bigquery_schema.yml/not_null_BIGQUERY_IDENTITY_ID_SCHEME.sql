select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ID_SCHEME
from GN_DW.SILVER.BIGQUERY_IDENTITY
where ID_SCHEME is null



      
    ) dbt_internal_test