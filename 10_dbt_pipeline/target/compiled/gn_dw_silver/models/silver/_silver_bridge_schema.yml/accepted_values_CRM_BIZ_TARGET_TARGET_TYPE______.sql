
    
    

with all_values as (

    select
        TARGET_TYPE as value_field,
        count(*) as n_records

    from GN_DW.SILVER.CRM_BIZ_TARGET
    group by TARGET_TYPE

)

select *
from all_values
where value_field not in (
    '당초','추경'
)


