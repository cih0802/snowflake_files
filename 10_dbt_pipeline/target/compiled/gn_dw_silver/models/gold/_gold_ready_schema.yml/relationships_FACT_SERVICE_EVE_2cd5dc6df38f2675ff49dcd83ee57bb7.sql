
    
    

with child as (
    select DATE_SK as from_field
    from GN_DW.GOLD.FACT_SERVICE_EVENT
    where DATE_SK is not null
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


