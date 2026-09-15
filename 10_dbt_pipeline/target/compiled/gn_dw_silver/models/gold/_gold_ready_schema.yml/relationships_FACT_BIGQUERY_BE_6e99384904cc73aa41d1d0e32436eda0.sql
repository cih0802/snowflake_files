
    
    

with child as (
    select BIGQUERY_EVENT_SK as from_field
    from GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR
    where BIGQUERY_EVENT_SK is not null
),

parent as (
    select BIGQUERY_EVENT_SK as to_field
    from GN_DW.GOLD.DIM_BIGQUERY_EVENT
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


