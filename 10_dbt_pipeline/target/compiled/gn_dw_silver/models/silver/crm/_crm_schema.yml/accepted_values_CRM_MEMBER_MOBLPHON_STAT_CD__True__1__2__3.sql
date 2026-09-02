
    
    

with all_values as (

    select
        MOBLPHON_STAT_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER where MOBLPHON_STAT_CD is not null) dbt_subquery
    group by MOBLPHON_STAT_CD

)

select *
from all_values
where value_field not in (
    '1','2','3'
)


