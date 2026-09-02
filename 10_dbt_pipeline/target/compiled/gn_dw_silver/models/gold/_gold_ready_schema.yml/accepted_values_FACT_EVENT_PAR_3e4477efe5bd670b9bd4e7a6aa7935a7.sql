
    
    

with all_values as (

    select
        PART_STATUS as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
    group by PART_STATUS

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5','6','110','120','130','140','150','160','170','180','190','200','210','220'
)


