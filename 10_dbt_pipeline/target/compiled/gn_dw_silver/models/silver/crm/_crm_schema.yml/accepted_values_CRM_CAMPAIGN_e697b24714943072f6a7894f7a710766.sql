
    
    

with all_values as (

    select
        CMMN_BRND as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMMN_BRND is not null) dbt_subquery
    group by CMMN_BRND

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5','6','7','8','9','10','11','12','13','14'
)


