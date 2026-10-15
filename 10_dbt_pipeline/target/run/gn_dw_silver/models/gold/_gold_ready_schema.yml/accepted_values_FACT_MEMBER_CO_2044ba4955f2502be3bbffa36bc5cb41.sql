select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        ACQ_GENDER as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_GENDER is not null) dbt_subquery
    group by ACQ_GENDER

)

select *
from all_values
where value_field not in (
    '국내(남자)','국내(여자)','외국인(남자)','외국인(여자)','외국인(기타)','단체','기업','기타'
)



      
    ) dbt_internal_test