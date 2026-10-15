
    
    

with all_values as (

    select
        STOP_CHANNEL as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where STOP_CHANNEL is not null) dbt_subquery
    group by STOP_CHANNEL

)

select *
from all_values
where value_field not in (
    '1','2','3'
)


