select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select MEMBER_DK as from_field
    from GN_DW.GOLD.FACT_MEMBER_MONTHLY
    where MEMBER_DK is not null
),

parent as (
    select MEMBER_DK as to_field
    from GN_DW.GOLD.DIM_MEMBER
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test