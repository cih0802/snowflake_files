select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    AD_PERF_DK || '|' || CASE_SEQ as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_AD_BROADCAST_CASE
where AD_PERF_DK || '|' || CASE_SEQ is not null
group by AD_PERF_DK || '|' || CASE_SEQ
having count(*) > 1



      
    ) dbt_internal_test