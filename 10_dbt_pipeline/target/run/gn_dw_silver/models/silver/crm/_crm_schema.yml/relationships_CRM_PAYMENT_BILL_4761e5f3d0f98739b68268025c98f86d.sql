select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select MBER_NO as from_field
    from GN_DW.SILVER.CRM_PAYMENT_BILLING
    where MBER_NO is not null
),

parent as (
    select MEMBER_DK as to_field
    from GN_DW.SILVER.CRM_MEMBER
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test