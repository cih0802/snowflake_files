select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        ACQ_AGE_BAND as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_AGE_BAND is not null) dbt_subquery
    group by ACQ_AGE_BAND

)

select *
from all_values
where value_field not in (
    '10대 미만','10대','20대','30대','40대','50대','60대','70대','70대 이상','단체','기업','기타'
)



      
    ) dbt_internal_test