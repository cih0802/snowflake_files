select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    LOG_SEQ as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_SEND_MEMBER_OPEN_LOG
where LOG_SEQ is not null
group by LOG_SEQ
having count(*) > 1



      
    ) dbt_internal_test