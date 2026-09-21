select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    CD_ID || '|' || DTL_CD_ID as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_MKTNG_CODE
where CD_ID || '|' || DTL_CD_ID is not null
group by CD_ID || '|' || DTL_CD_ID
having count(*) > 1



      
    ) dbt_internal_test