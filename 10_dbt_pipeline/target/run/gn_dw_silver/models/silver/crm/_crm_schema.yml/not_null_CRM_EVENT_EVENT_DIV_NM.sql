select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select EVENT_DIV_NM
from (select * from GN_DW.SILVER.CRM_EVENT where EVENT_DIV_CD is not null) dbt_subquery
where EVENT_DIV_NM is null



      
    ) dbt_internal_test