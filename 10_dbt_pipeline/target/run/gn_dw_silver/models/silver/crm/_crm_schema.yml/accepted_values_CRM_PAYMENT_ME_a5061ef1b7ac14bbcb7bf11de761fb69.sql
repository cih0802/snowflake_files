select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        CRTFC_MTH_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_PAYMENT_METHOD where CRTFC_MTH_CD is not null) dbt_subquery
    group by CRTFC_MTH_CD

)

select *
from all_values
where value_field not in (
    '1','2','4','5','7'
)



      
    ) dbt_internal_test