select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        MBRFEE_PRCS_STAT_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_PAYMENT_BILLING where MBRFEE_PRCS_STAT_CD is not null) dbt_subquery
    group by MBRFEE_PRCS_STAT_CD

)

select *
from all_values
where value_field not in (
    'F','R','S'
)



      
    ) dbt_internal_test