
    
    

with all_values as (

    select
        SEX as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER where SEX is not null) dbt_subquery
    group by SEX

)

select *
from all_values
where value_field not in (
    '0','1','2','3','4','5','6','7','8'
)


