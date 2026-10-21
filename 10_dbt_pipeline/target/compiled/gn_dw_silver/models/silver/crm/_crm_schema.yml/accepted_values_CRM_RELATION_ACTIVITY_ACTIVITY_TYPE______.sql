
    
    

with all_values as (

    select
        ACTIVITY_TYPE as value_field,
        count(*) as n_records

    from GN_DW.SILVER.CRM_RELATION_ACTIVITY
    group by ACTIVITY_TYPE

)

select *
from all_values
where value_field not in (
    '서신','선물금'
)


