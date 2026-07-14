select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    SERVICE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_SERVICE
where SERVICE_SK is not null
group by SERVICE_SK
having count(*) > 1



      
    ) dbt_internal_test