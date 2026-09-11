select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        EMAIL_STAT_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_MEMBER where EMAIL_STAT_CD is not null) dbt_subquery
    group by EMAIL_STAT_CD

)

select *
from all_values
where value_field not in (
    '0','1','2','3'
)



      
    ) dbt_internal_test