
    
    

with child as (
    select SERVICE_SK as from_field
    from (select * from GN_DW.GOLD.FACT_SERVICE_EVENT where SERVICE_SK != 0) dbt_subquery
    where SERVICE_SK is not null
),

parent as (
    select SERVICE_SK as to_field
    from GN_DW.GOLD.DIM_SERVICE
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


