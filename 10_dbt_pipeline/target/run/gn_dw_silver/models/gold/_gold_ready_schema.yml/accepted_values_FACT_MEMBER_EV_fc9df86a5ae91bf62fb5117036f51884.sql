select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        DVLP_DIV_NM as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where DVLP_DIV_NM is not null) dbt_subquery
    group by DVLP_DIV_NM

)

select *
from all_values
where value_field not in (
    '신규','증액','감액','재후원','후원중단'
)



      
    ) dbt_internal_test