
    
    

with all_values as (

    select
        DEV_TYPE as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_TARGET_DEV
    group by DEV_TYPE

)

select *
from all_values
where value_field not in (
    '1','2','4'
)


