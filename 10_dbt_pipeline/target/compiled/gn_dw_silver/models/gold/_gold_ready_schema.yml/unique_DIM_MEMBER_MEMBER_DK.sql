
    
    

select
    MEMBER_DK as unique_field,
    count(*) as n_records

from (select * from GN_DW.GOLD.DIM_MEMBER where IS_CURRENT = TRUE) dbt_subquery
where MEMBER_DK is not null
group by MEMBER_DK
having count(*) > 1


