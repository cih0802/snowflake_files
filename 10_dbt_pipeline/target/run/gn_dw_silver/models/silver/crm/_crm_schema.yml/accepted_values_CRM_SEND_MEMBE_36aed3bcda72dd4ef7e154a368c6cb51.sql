select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        SEND_RESULT_GROUP as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_SEND_MEMBER where SEND_RESULT_GROUP is not null) dbt_subquery
    group by SEND_RESULT_GROUP

)

select *
from all_values
where value_field not in (
    'MS056','MS057','MS058','MS059'
)



      
    ) dbt_internal_test