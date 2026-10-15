select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MONTH_KEY || '|' || SPONSORSHIP_SK || '|' || COALESCE(FEE_DIV_CD,'~') || '|' || COALESCE(PAYMENT_TYPE,'~') || '|' || COALESCE(RQEST_DIV_CD,'~') || '|' || COALESCE(PRCS_STAT_CD,'~') || '|' || COALESCE(RETUN_RSN_CD,'~') || '|' || CAMPAIGN_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS
where MONTH_KEY || '|' || SPONSORSHIP_SK || '|' || COALESCE(FEE_DIV_CD,'~') || '|' || COALESCE(PAYMENT_TYPE,'~') || '|' || COALESCE(RQEST_DIV_CD,'~') || '|' || COALESCE(PRCS_STAT_CD,'~') || '|' || COALESCE(RETUN_RSN_CD,'~') || '|' || CAMPAIGN_SK is not null
group by MONTH_KEY || '|' || SPONSORSHIP_SK || '|' || COALESCE(FEE_DIV_CD,'~') || '|' || COALESCE(PAYMENT_TYPE,'~') || '|' || COALESCE(RQEST_DIV_CD,'~') || '|' || COALESCE(PRCS_STAT_CD,'~') || '|' || COALESCE(RETUN_RSN_CD,'~') || '|' || CAMPAIGN_SK
having count(*) > 1



      
    ) dbt_internal_test