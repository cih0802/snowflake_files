select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select SPNSR_BSNS_ID as from_field
    from (select * from GN_DW.SILVER.CRM_SPONSOR_RELATION where SPNSR_BSNS_ID IS NOT NULL) dbt_subquery
    where SPNSR_BSNS_ID is not null
),

parent as (
    select SPNSR_BSNS_ID as to_field
    from GN_DW.SILVER.CRM_SPONSORSHIP
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test