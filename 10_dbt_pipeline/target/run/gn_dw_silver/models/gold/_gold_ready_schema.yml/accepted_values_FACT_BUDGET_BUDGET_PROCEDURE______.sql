select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        BUDGET_PROCEDURE as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_BUDGET
    group by BUDGET_PROCEDURE

)

select *
from all_values
where value_field not in (
    '연사업','추가경정'
)



      
    ) dbt_internal_test