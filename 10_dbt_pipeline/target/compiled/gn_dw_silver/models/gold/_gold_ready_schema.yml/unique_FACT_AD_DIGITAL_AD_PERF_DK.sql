
    
    

select
    AD_PERF_DK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_AD_DIGITAL
where AD_PERF_DK is not null
group by AD_PERF_DK
having count(*) > 1


