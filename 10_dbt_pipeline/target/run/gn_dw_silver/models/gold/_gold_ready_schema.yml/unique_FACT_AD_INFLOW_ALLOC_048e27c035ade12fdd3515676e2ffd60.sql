select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MONTH_KEY || '|' || MKTG_CAMPAIGN_SK || '|' || COALESCE(INFLOW_PATH, '~') || '|' || ROW_KIND || '|' || COALESCE(UNALLOC_REASON, '~') as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_AD_INFLOW_ALLOC
where MONTH_KEY || '|' || MKTG_CAMPAIGN_SK || '|' || COALESCE(INFLOW_PATH, '~') || '|' || ROW_KIND || '|' || COALESCE(UNALLOC_REASON, '~') is not null
group by MONTH_KEY || '|' || MKTG_CAMPAIGN_SK || '|' || COALESCE(INFLOW_PATH, '~') || '|' || ROW_KIND || '|' || COALESCE(UNALLOC_REASON, '~')
having count(*) > 1



      
    ) dbt_internal_test