
    
    

with child as (
    select CAMPAIGN_SK as from_field
    from (select * from GN_DW.GOLD.FACT_EVENT_PARTICIPATION where CAMPAIGN_SK != 0) dbt_subquery
    where CAMPAIGN_SK is not null
),

parent as (
    select CAMPAIGN_SK as to_field
    from GN_DW.GOLD.DIM_CAMPAIGN
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


