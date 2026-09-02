select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select AD_PERF_DK as from_field
    from GN_DW.SILVER.AGENCY_AD_DIGITAL
    where AD_PERF_DK is not null
),

parent as (
    select AD_PERF_DK as to_field
    from GN_DW.SILVER.AGENCY_AD_ROW_DGT
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test