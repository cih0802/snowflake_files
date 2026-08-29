
    
    

with all_values as (

    select
        CMPGN_TYPE1_NM as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMPGN_TYPE1_NM IS NOT NULL) dbt_subquery
    group by CMPGN_TYPE1_NM

)

select *
from all_values
where value_field not in (
    '국내','통합','해외'
)


