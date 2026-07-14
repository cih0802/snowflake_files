select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    EVENT_NAME as unique_field,
    count(*) as n_records

from GN_DW.SILVER.GA4_EVENT_DIM
where EVENT_NAME is not null
group by EVENT_NAME
having count(*) > 1



      
    ) dbt_internal_test