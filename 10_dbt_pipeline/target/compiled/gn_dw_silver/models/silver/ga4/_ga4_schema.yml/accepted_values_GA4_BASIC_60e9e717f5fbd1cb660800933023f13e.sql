
    
    

with all_values as (

    select
        ID_SCHEME as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.GA4_BASIC where ID_SCHEME IS NOT NULL) dbt_subquery
    group by ID_SCHEME

)

select *
from all_values
where value_field not in (
    'MBER_NO','ONCE_MBER_NO','APP','EMAIL','INVALID','UNCLASSIFIED'
)


