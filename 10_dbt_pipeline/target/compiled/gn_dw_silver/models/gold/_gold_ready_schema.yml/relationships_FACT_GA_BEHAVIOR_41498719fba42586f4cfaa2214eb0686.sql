
    
    

with child as (
    select IDENTITY_SK as from_field
    from (select * from GN_DW.GOLD.FACT_GA_BEHAVIOR where IDENTITY_SK != 0) dbt_subquery
    where IDENTITY_SK is not null
),

parent as (
    select IDENTITY_SK as to_field
    from GN_DW.GOLD.DIM_MEMBER_IDENTITY
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


