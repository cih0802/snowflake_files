
    
    

with all_values as (

    select
        STOP_REASON_NM as value_field,
        count(*) as n_records

    from (select * from GN_DW.GOLD.FACT_MEMBER_EVENT where STOP_REASON_NM is not null) dbt_subquery
    group by STOP_REASON_NM

)

select *
from all_values
where value_field not in (
    '기타','명의변경','반송미납','신규미납','아동퇴소','약정후원','이중가입','장기미납','회원항의','다른곳지원','사업장종결','지라니기타','지라니부재','지라니이관','기업후원종료','일시후원이었음','만18세아동퇴소','은행자동납부해지','개인(경제적)사유','지라니TS후원중단'
)


