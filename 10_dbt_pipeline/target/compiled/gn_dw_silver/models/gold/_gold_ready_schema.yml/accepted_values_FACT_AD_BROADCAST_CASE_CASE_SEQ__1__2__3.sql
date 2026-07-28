
    
    

with all_values as (

    select
        CASE_SEQ as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_AD_BROADCAST_CASE
    group by CASE_SEQ

)

select *
from all_values
where value_field not in (
    '1','2','3'
)


