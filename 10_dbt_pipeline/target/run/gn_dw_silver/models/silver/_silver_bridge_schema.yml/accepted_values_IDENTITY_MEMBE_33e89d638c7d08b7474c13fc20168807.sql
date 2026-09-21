select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        MATCH_METHOD as value_field,
        count(*) as n_records

    from GN_DW.SILVER.IDENTITY_MEMBER_XREF
    group by MATCH_METHOD

)

select *
from all_values
where value_field not in (
    'MEMBER_ID_EXACT','UNMATCHED','NOT_A_MEMBER_ID'
)



      
    ) dbt_internal_test