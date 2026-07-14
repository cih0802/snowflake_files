select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    CMPGN_CD as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_CAMPAIGN
where CMPGN_CD is not null
group by CMPGN_CD
having count(*) > 1



      
    ) dbt_internal_test