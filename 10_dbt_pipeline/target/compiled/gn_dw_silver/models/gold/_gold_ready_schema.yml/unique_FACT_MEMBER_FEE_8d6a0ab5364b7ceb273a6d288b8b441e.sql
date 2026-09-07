
    
    

select
    MONTH_KEY || '|' || MEMBER_DK || '|' || SPONSORSHIP_SK || '|' || PAYMENT_SK || '|' || COALESCE(FEE_DIV_CD,'~') || '|' || COALESCE(PAYMENT_TYPE,'~') || '|' || COALESCE(SETLE_CD,'~') as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_MEMBER_FEE
where MONTH_KEY || '|' || MEMBER_DK || '|' || SPONSORSHIP_SK || '|' || PAYMENT_SK || '|' || COALESCE(FEE_DIV_CD,'~') || '|' || COALESCE(PAYMENT_TYPE,'~') || '|' || COALESCE(SETLE_CD,'~') is not null
group by MONTH_KEY || '|' || MEMBER_DK || '|' || SPONSORSHIP_SK || '|' || PAYMENT_SK || '|' || COALESCE(FEE_DIV_CD,'~') || '|' || COALESCE(PAYMENT_TYPE,'~') || '|' || COALESCE(SETLE_CD,'~')
having count(*) > 1


