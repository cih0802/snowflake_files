
    
    

with child as (
    select SPONSORSHIP_SK as from_field
    from (select * from GN_DW.GOLD.FACT_EVENT_PARTICIPATION where SPONSORSHIP_SK != 0) dbt_subquery
    where SPONSORSHIP_SK is not null
),

parent as (
    select SPONSORSHIP_SK as to_field
    from GN_DW.GOLD.DIM_SPONSORSHIP
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


