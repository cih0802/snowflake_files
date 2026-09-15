
    
    

with all_values as (

    select
        ACQ_AGE_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_AGE_CD is not null) dbt_subquery
    group by ACQ_AGE_CD

)

select *
from all_values
where value_field not in (
    1,2,3,4,5,6,7,8,9,10,11,12
)


