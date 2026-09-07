
    
    

with child as (
    select DEPT_ID as from_field
    from (select * from GN_DW.SILVER.CRM_DEV_TARGET where DEPT_ID IS NOT NULL) dbt_subquery
    where DEPT_ID is not null
),

parent as (
    select DEPT_ID as to_field
    from GN_DW.SILVER.CRM_ORG
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


