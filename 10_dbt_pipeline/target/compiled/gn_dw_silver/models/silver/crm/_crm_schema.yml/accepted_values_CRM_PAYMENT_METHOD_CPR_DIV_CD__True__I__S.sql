
    
    

with all_values as (

    select
        CPR_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_PAYMENT_METHOD where CPR_DIV_CD is not null) dbt_subquery
    group by CPR_DIV_CD

)

select *
from all_values
where value_field not in (
    'I','S'
)


