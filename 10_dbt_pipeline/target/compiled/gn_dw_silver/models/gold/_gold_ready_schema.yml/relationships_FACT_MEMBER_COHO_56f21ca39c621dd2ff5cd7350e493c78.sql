
    
    

with child as (
    select FIRST_STOP_DATE_SK as from_field
    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where FIRST_STOP_DATE_SK is not null and FIRST_STOP_DATE_SK != 0) dbt_subquery
    where FIRST_STOP_DATE_SK is not null
),

parent as (
    select DATE_SK as to_field
    from GN_DW.GOLD.DIM_DATE
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


