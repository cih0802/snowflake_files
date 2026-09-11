select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SEND_TYPE_BK
from GN_DW.GOLD.DIM_SEND_TYPE
where SEND_TYPE_BK is null



      
    ) dbt_internal_test