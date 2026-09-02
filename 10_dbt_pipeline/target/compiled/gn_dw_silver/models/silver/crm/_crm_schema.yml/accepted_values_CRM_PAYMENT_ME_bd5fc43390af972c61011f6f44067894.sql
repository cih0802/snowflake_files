
    
    

with all_values as (

    select
        APPLCNT_MBER_REL_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_PAYMENT_METHOD where APPLCNT_MBER_REL_CD is not null) dbt_subquery
    group by APPLCNT_MBER_REL_CD

)

select *
from all_values
where value_field not in (
    '0','1','2','3','4','5','6','7','8','9','10','11','12','13'
)


