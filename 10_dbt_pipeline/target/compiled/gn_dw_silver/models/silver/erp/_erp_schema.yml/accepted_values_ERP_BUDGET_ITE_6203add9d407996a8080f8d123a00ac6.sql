
    
    

with all_values as (

    select
        BDGT_UNIT_NM as value_field,
        count(*) as n_records

    from GN_DW.SILVER.ERP_BUDGET_ITEM
    group by BDGT_UNIT_NM

)

select *
from all_values
where value_field not in (
    '데이터분석센터','마케팅기획1팀','마케팅기획2팀','매체운영팀','콘텐츠기획팀','사회복지법인예산'
)


