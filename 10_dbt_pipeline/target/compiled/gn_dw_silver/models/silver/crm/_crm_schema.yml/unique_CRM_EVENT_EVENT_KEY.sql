
    
    

select
    EVENT_KEY as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_EVENT
where EVENT_KEY is not null
group by EVENT_KEY
having count(*) > 1


