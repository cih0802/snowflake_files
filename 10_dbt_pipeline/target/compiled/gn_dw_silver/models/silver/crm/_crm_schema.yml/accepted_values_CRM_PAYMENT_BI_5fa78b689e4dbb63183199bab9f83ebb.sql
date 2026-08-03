
    
    

with all_values as (

    select
        RETUN_RSN_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_PAYMENT_BILLING where RETUN_RSN_CD is not null) dbt_subquery
    group by RETUN_RSN_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5','6','7','8','9','10','11'
)


