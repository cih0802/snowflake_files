select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        EVENT_KIND_NAME as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
    group by EVENT_KIND_NAME

)

select *
from all_values
where value_field not in (
    '일반행사','캠페인행사'
)



      
    ) dbt_internal_test