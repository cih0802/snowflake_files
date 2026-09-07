
    
    

with all_values as (

    select
        CAMPAIGN_STOP_CNT as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_MEMBER_EVENT
    group by CAMPAIGN_STOP_CNT

)

select *
from all_values
where value_field not in (
    0,1
)


