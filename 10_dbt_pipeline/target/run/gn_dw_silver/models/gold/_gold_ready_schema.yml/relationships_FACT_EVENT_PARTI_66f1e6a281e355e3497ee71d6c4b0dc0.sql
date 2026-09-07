select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select DATE_SK as from_field
    from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
    where DATE_SK is not null
),

parent as (
    select DATE_SK as to_field
    from GN_DW.GOLD.DIM_DATE
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test