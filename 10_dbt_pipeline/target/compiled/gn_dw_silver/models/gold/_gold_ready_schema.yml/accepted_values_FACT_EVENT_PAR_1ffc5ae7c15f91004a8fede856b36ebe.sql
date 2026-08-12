
    
    

with all_values as (

    select
        EVENT_KIND as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
    group by EVENT_KIND

)

select *
from all_values
where value_field not in (
    'EVENT','CRMN'
)


