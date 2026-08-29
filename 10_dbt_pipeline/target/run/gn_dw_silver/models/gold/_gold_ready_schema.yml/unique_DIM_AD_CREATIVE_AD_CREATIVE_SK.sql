select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    AD_CREATIVE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_AD_CREATIVE
where AD_CREATIVE_SK is not null
group by AD_CREATIVE_SK
having count(*) > 1



      
    ) dbt_internal_test