select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select MEMBER_SK
from GN_DW.GOLD.DIM_MEMBER
where MEMBER_SK is null



      
    ) dbt_internal_test