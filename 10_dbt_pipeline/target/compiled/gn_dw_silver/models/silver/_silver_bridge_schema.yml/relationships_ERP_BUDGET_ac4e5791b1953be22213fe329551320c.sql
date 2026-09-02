
    
    

with child as (
    select BUDGET_ITEM_DK as from_field
    from GN_DW.SILVER.ERP_BUDGET
    where BUDGET_ITEM_DK is not null
),

parent as (
    select BUDGET_ITEM_DK as to_field
    from GN_DW.SILVER.ERP_BUDGET_ITEM
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


