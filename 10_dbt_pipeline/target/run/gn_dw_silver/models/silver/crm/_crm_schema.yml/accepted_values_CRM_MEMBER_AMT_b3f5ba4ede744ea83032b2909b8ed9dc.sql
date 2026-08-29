select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        SPNSR_AMT_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE where SPNSR_AMT_CD is not null) dbt_subquery
    group by SPNSR_AMT_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5'
)



      
    ) dbt_internal_test