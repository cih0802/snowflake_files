
    
    

with child as (
    select MEMBER_DK as from_field
    from GN_DW.SILVER.IDENTITY_MEMBER_XREF
    where MEMBER_DK is not null
),

parent as (
    select MEMBER_DK as to_field
    from GN_DW.SILVER.CRM_MEMBER
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


