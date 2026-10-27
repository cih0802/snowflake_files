select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        ROW_KIND as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_AD_INFLOW_ALLOC
    group by ROW_KIND

)

select *
from all_values
where value_field not in (
    'ALLOC','NOT_ALLOWED','UNALLOC'
)



      
    ) dbt_internal_test