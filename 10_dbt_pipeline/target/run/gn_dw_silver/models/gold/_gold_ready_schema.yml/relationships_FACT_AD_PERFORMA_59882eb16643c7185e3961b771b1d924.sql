select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select MKTG_CAMPAIGN_SK as from_field
    from GN_DW.GOLD.FACT_AD_PERFORMANCE
    where MKTG_CAMPAIGN_SK is not null
),

parent as (
    select MKTG_CAMPAIGN_SK as to_field
    from GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test