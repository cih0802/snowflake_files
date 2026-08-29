select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select IDENTITY_SK
from GN_DW.GOLD.DIM_MEMBER_IDENTITY
where IDENTITY_SK is null



      
    ) dbt_internal_test