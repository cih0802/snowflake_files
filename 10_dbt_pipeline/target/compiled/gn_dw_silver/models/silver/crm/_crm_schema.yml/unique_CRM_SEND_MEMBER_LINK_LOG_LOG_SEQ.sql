
    
    

select
    LOG_SEQ as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_SEND_MEMBER_LINK_LOG
where LOG_SEQ is not null
group by LOG_SEQ
having count(*) > 1


