select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    ACTIVITY_KEY as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_RELATION_ACTIVITY
where ACTIVITY_KEY is not null
group by ACTIVITY_KEY
having count(*) > 1



      
    ) dbt_internal_test