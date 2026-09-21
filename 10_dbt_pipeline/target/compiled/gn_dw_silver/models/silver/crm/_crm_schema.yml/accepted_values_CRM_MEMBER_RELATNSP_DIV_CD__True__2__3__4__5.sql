
    
    

with all_values as (

    select
        RELATNSP_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER where RELATNSP_DIV_CD is not null) dbt_subquery
    group by RELATNSP_DIV_CD

)

select *
from all_values
where value_field not in (
    '2','3','4','5'
)


