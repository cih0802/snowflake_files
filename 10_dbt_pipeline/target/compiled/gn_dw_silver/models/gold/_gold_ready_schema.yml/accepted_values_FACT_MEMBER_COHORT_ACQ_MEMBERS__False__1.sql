
    
    

with all_values as (

    select
        ACQ_MEMBERS as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_MEMBER_COHORT
    group by ACQ_MEMBERS

)

select *
from all_values
where value_field not in (
    1
)


