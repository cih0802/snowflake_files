
    
    

with child as (
    select SPNSR_BSNS_ID as from_field
    from GN_DW.SILVER.CRM_MEMBER_SPONSOR_BIZ
    where SPNSR_BSNS_ID is not null
),

parent as (
    select SPNSR_BSNS_ID as to_field
    from GN_DW.SILVER.CRM_SPONSORSHIP
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


