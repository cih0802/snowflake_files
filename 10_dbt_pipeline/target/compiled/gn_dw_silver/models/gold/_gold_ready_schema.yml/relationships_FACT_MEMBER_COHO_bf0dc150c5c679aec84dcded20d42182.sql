
    
    

with child as (
    select ACQ_ORG_SK as from_field
    from GN_DW.GOLD.FACT_MEMBER_COHORT
    where ACQ_ORG_SK is not null
),

parent as (
    select ORG_SK as to_field
    from GN_DW.GOLD.DIM_ORG
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


