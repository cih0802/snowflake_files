
    
    

with child as (
    select SNDNG_KEY as from_field
    from GN_DW.SILVER.CRM_SEND_RESULT
    where SNDNG_KEY is not null
),

parent as (
    select SNDNG_KEY as to_field
    from GN_DW.SILVER.CRM_SEND_REQUEST
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


