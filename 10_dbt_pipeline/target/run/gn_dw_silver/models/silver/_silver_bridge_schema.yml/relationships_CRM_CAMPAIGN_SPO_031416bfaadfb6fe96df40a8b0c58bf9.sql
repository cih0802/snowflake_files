select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select CMPGN_CD as from_field
    from GN_DW.SILVER.CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE
    where CMPGN_CD is not null
),

parent as (
    select CMPGN_CD as to_field
    from GN_DW.SILVER.CRM_CAMPAIGN
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test