select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select EVENT_KEY as from_field
    from GN_DW.SILVER.CRM_EVENT_PARTICIPATION
    where EVENT_KEY is not null
),

parent as (
    select EVENT_KEY as to_field
    from GN_DW.SILVER.CRM_EVENT
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test