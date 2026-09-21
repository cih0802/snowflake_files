select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MBER_NO || '|' || SPNSR_BSNS_NO as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN
where MBER_NO || '|' || SPNSR_BSNS_NO is not null
group by MBER_NO || '|' || SPNSR_BSNS_NO
having count(*) > 1



      
    ) dbt_internal_test