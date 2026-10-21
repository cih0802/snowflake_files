
    
    

select
    ACTIVITY_KEY as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_RELATION_ACTIVITY
where ACTIVITY_KEY is not null
group by ACTIVITY_KEY
having count(*) > 1


