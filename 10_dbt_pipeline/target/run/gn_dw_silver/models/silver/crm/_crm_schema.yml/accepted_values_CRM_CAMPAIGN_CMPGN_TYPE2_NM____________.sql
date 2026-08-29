select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        CMPGN_TYPE2_NM as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMPGN_TYPE2_NM IS NOT NULL) dbt_subquery
    group by CMPGN_TYPE2_NM

)

select *
from all_values
where value_field not in (
    '굿즈','기타','사례','사업'
)



      
    ) dbt_internal_test