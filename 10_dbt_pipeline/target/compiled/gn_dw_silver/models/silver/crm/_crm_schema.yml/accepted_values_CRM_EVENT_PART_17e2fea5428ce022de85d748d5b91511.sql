
    
    

with all_values as (

    select
        PARTCPT_CHNNL_GROUP as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION where PARTCPT_CHNNL_GROUP is not null) dbt_subquery
    group by PARTCPT_CHNNL_GROUP

)

select *
from all_values
where value_field not in (
    'MS302'
)


