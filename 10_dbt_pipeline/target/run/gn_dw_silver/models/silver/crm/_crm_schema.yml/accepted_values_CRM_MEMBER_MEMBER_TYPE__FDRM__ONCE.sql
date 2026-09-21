select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        MEMBER_TYPE as value_field,
        count(*) as n_records

    from GN_DW.SILVER.CRM_MEMBER
    group by MEMBER_TYPE

)

select *
from all_values
where value_field not in (
    'FDRM','ONCE'
)



      
    ) dbt_internal_test