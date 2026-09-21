select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    SPNSR_BSNS_ID as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_SPONSORSHIP
where SPNSR_BSNS_ID is not null
group by SPNSR_BSNS_ID
having count(*) > 1



      
    ) dbt_internal_test