select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MATCH_METHOD
from GN_DW.SILVER.IDENTITY_MEMBER_XREF
where MATCH_METHOD is null



      
    ) dbt_internal_test