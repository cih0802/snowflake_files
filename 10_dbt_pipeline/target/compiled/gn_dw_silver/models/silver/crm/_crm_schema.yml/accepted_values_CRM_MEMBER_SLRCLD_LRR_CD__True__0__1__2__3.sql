
    
    

with all_values as (

    select
        SLRCLD_LRR_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER where SLRCLD_LRR_CD is not null) dbt_subquery
    group by SLRCLD_LRR_CD

)

select *
from all_values
where value_field not in (
    '0','1','2','3'
)


