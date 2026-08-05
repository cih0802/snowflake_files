
    
    

with all_values as (

    select
        ACQ_REGION as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_REGION is not null) dbt_subquery
    group by ACQ_REGION

)

select *
from all_values
where value_field not in (
    '서울','경기','인천','강원','대전','충남','충북','광주','전북','전남','대구','경북','경남','울산','부산','제주','기타','세종'
)


