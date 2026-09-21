
    
    

with all_values as (

    select
        MSG_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_SEND_REQUEST where MSG_DIV_CD is not null) dbt_subquery
    group by MSG_DIV_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4'
)


