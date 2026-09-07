
    
    

with all_values as (

    select
        AGE_BAND as value_field,
        count(*) as n_records

    from GN_DW.GOLD.DIM_MEMBER
    group by AGE_BAND

)

select *
from all_values
where value_field not in (
    '10대 미만','10대','20대','30대','40대','50대','60대','70대','70대 이상','단체','기업','기타'
)


