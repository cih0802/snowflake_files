select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        REGION_AT_EVENT as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where REGION_AT_EVENT is not null) dbt_subquery
    group by REGION_AT_EVENT

)

select *
from all_values
where value_field not in (
    '서울','경기','인천','강원','대전','충남','충북','광주','전북','전남','대구','경북','경남','울산','부산','제주','기타','세종'
)



      
    ) dbt_internal_test