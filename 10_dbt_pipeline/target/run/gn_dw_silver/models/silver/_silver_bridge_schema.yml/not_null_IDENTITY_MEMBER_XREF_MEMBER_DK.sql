select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MEMBER_DK
from (select * from GN_DW.SILVER.IDENTITY_MEMBER_XREF where MATCH_METHOD = 'MEMBER_ID_EXACT') dbt_subquery
where MEMBER_DK is null



      
    ) dbt_internal_test