select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        EVENT_DIV_GROUP as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_EVENT where EVENT_DIV_GROUP is not null) dbt_subquery
    group by EVENT_DIV_GROUP

)

select *
from all_values
where value_field not in (
    'MS286','MS002'
)



      
    ) dbt_internal_test