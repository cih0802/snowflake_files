
    
    

with child as (
    select CMPGN_CD as from_field
    from (select * from GN_DW.SILVER.CRM_MEMBER_DEV where CMPGN_CD IS NOT NULL) dbt_subquery
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


