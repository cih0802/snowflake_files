
    
    

with all_values as (

    select
        PSTMTR_PRCS_STAT_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.SILVER.CRM_SEND_REQUEST where PSTMTR_PRCS_STAT_CD is not null) dbt_subquery
    group by PSTMTR_PRCS_STAT_CD

)

select *
from all_values
where value_field not in (
    '0','1'
)


