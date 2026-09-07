
    
    

with child as (
    select SEND_TYPE_SK as from_field
    from GN_DW.GOLD.FACT_SERVICE_EVENT
    where SEND_TYPE_SK is not null
),

parent as (
    select SEND_TYPE_SK as to_field
    from GN_DW.GOLD.DIM_SEND_TYPE
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


