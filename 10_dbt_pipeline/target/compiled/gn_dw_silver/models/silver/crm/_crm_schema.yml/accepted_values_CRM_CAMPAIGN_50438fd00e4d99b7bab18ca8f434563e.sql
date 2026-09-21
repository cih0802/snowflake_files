
    
    

with all_values as (

    select
        CMPGN_TRGET_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMPGN_TRGET_CD is not null) dbt_subquery
    group by CMPGN_TRGET_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5','6','9','10','11','13'
)


