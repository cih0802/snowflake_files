select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MBER_NO || '|' || ONCE_MBER_NO as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_MEMBER_CONVERT_HIST
where MBER_NO || '|' || ONCE_MBER_NO is not null
group by MBER_NO || '|' || ONCE_MBER_NO
having count(*) > 1



      
    ) dbt_internal_test