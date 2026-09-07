
    
    

with all_values as (

    select
        REGION as value_field,
        count(*) as n_records

    from GN_DW.GOLD.DIM_MEMBER
    group by REGION

)

select *
from all_values
where value_field not in (
    '서울','경기','인천','강원','대전','충남','충북','광주','전북','전남','대구','경북','경남','울산','부산','제주','기타','세종'
)


