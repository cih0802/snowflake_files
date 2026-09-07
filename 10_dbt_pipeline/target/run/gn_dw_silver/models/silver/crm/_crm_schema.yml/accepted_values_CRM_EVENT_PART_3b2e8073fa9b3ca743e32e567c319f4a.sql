select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        PARTCPT_PATH_GROUP as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION where PARTCPT_PATH_GROUP is not null) dbt_subquery
    group by PARTCPT_PATH_GROUP

)

select *
from all_values
where value_field not in (
    'MS303','MS004'
)



      
    ) dbt_internal_test