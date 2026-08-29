
    
    

with child as (
    select AD_PERF_DK as from_field
    from GN_DW.GOLD.FACT_AD_BROADCAST_CASE
    where AD_PERF_DK is not null
),

parent as (
    select AD_PERF_DK as to_field
    from GN_DW.GOLD.FACT_AD_PERFORMANCE
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


