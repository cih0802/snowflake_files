
    
    

with all_values as (

    select
        DATA_TYPE_NM as value_field,
        count(*) as n_records

    from GN_DW.GOLD.WIDE_MBRFEE_PRDT_ACTL
    group by DATA_TYPE_NM

)

select *
from all_values
where value_field not in (
    '예측','실적','연도초예측','연초예측'
)


