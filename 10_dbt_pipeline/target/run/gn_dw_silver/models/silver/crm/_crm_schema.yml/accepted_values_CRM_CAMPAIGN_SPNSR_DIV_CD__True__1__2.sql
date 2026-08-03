select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        SPNSR_DIV_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_CAMPAIGN where SPNSR_DIV_CD is not null) dbt_subquery
    group by SPNSR_DIV_CD

)

select *
from all_values
where value_field not in (
    '1','2'
)



      
    ) dbt_internal_test