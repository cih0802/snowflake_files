
    
    

with all_values as (

    select
        AD_TYPE as value_field,
        count(*) as n_records

    from GN_DW.SILVER.AGENCY_AD_PERFORMANCE
    group by AD_TYPE

)

select *
from all_values
where value_field not in (
    'DIGITAL','VIDEO','REBROADCAST'
)


