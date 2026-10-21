
    
    

with all_values as (

    select
        RQEST_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_PAYMENT_BILLING where RQEST_DIV_CD is not null) dbt_subquery
    group by RQEST_DIV_CD

)

select *
from all_values
where value_field not in (
    '1','2','9','Y'
)


