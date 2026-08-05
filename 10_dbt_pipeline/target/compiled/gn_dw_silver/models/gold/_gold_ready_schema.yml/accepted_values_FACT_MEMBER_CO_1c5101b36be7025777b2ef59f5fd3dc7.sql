
    
    

with all_values as (

    select
        ACQ_AREA_CD as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_AREA_CD is not null) dbt_subquery
    group by ACQ_AREA_CD

)

select *
from all_values
where value_field not in (
    '0','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18'
)


