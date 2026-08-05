select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        AGE_BAND_AT_EVENT as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where AGE_BAND_AT_EVENT is not null) dbt_subquery
    group by AGE_BAND_AT_EVENT

)

select *
from all_values
where value_field not in (
    '10대 미만','10대','20대','30대','40대','50대','60대','70대','70대 이상','단체','기업','기타'
)



      
    ) dbt_internal_test