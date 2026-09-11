
    
    

with all_values as (

    select
        ETC_TSTM_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER where ETC_TSTM_DIV_CD is not null) dbt_subquery
    group by ETC_TSTM_DIV_CD

)

select *
from all_values
where value_field not in (
    '0','1','2','3'
)


