
    
    

with all_values as (

    select
        SETLE_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE where SETLE_CD is not null) dbt_subquery
    group by SETLE_CD

)

select *
from all_values
where value_field not in (
    '1','2','4','5','8','11','12'
)


