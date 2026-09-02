select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MEMBER_DK || '|' || SPNSR_BSNS_NO as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ
where MEMBER_DK || '|' || SPNSR_BSNS_NO is not null
group by MEMBER_DK || '|' || SPNSR_BSNS_NO
having count(*) > 1



      
    ) dbt_internal_test