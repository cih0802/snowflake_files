select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        CANCL_RDCAMT_RSN_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER_DEV where CANCL_RDCAMT_RSN_CD is not null) dbt_subquery
    group by CANCL_RDCAMT_RSN_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','20','21','22','23','24','25','26','27','28','29','30','31','32','33'
)



      
    ) dbt_internal_test