select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        DSCNTC_PATH_NM as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER_DISCONTINUE where DSCNTC_PATH_NM is not null) dbt_subquery
    group by DSCNTC_PATH_NM

)

select *
from all_values
where value_field not in (
    'CRM','홈페이지','SYSTEM'
)



      
    ) dbt_internal_test