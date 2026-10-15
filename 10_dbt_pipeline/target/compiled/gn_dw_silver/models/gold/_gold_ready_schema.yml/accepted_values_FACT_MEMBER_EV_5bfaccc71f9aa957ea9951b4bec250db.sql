
    
    

with all_values as (

    select
        DEV_EXCL_REASON as value_field,
        count(*) as n_records

    from GN_DW.GOLD.FACT_MEMBER_EVENT
    group by DEV_EXCL_REASON

)

select *
from all_values
where value_field not in (
    '동월중단','사업월상계','회원월상계','누적상계','부분상계','후원사업없음','원금액0이하'
)


