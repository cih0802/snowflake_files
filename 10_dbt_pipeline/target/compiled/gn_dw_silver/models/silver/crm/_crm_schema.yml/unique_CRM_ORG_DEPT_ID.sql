
    
    

select
    DEPT_ID as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_ORG
where DEPT_ID is not null
group by DEPT_ID
having count(*) > 1


