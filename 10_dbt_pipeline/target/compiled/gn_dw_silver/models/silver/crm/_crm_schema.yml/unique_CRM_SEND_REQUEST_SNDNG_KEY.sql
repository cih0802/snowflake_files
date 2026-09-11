
    
    

select
    SNDNG_KEY as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_SEND_REQUEST
where SNDNG_KEY is not null
group by SNDNG_KEY
having count(*) > 1


