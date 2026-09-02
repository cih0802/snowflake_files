select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        AGE_AT_EVENT as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where AGE_AT_EVENT is not null) dbt_subquery
    group by AGE_AT_EVENT

)

select *
from all_values
where value_field not in (
    1,2,3,4,5,6,7,8,9,10,11,12
)



      
    ) dbt_internal_test