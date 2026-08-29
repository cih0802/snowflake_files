select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select SEND_TYPE_L
from GN_DW.GOLD.DIM_SEND_TYPE
where SEND_TYPE_L is null



      
    ) dbt_internal_test