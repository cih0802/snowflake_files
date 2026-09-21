select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    EVENT_KEY as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_EVENT
where EVENT_KEY is not null
group by EVENT_KEY
having count(*) > 1



      
    ) dbt_internal_test