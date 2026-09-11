select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    SNDNG_KEY as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_SEND_REQUEST
where SNDNG_KEY is not null
group by SNDNG_KEY
having count(*) > 1



      
    ) dbt_internal_test