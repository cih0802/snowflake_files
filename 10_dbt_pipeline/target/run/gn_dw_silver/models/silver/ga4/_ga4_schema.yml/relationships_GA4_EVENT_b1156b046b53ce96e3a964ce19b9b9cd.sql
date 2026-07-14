select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select EVENT_NAME as from_field
    from GN_DW.SILVER.GA4_EVENT
    where EVENT_NAME is not null
),

parent as (
    select EVENT_NAME as to_field
    from GN_DW.SILVER.GA4_EVENT_DIM
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test