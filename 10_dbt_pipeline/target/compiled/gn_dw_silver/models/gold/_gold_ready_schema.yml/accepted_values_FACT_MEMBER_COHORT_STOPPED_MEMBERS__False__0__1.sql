
    
    

with all_values as (

    select
        STOPPED_MEMBERS as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_MEMBER_COHORT
    group by STOPPED_MEMBERS

)

select *
from all_values
where value_field not in (
    0,1
)


