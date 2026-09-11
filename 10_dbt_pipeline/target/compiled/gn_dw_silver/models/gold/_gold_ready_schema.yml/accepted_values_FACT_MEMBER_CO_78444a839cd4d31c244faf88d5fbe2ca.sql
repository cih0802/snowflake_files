
    
    

with all_values as (

    select
        ACQ_DVLP_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_DVLP_DIV_CD is not null) dbt_subquery
    group by ACQ_DVLP_DIV_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5'
)


