select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        IS_STOPPED_OBS as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_MEMBER_COHORT
    group by IS_STOPPED_OBS

)

select *
from all_values
where value_field not in (
    0,1
)



      
    ) dbt_internal_test