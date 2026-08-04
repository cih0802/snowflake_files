
    
    

with all_values as (

    select
        PREV_MEMBER_STATUS_NAME as value_field,
        count(*) as n_records

    from GN_DW.GOLD.DIM_MEMBER
    group by PREV_MEMBER_STATUS_NAME

)

select *
from all_values
where value_field not in (
    '활동회원','신규미납1','신규미납2','신규미납3','신규미납4','신규미납5','장기미납1','장기미납2','장기미납3','장기미납4','장기미납5','후원중단'
)


