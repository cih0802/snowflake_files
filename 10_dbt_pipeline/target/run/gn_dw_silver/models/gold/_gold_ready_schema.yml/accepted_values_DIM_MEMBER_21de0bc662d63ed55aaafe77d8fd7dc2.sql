select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        PREV_MBER_STAT_CD as value_field,
        count(*) as n_records

    from GN_DW.GOLD.DIM_MEMBER
    group by PREV_MBER_STAT_CD

)

select *
from all_values
where value_field not in (
    '1','2','3','4','5','6','7','8','9','10','11','12'
)



      
    ) dbt_internal_test