select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        STOP_REASON as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where STOP_REASON is not null) dbt_subquery
    group by STOP_REASON

)

select *
from all_values
where value_field not in (
    '1','8','9','11','13','14','15','16','17','20','21','22','23','25','26','27','28','29','30','31'
)



      
    ) dbt_internal_test