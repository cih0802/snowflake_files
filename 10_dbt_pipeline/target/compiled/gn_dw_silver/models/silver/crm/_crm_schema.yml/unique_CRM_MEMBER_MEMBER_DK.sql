
    
    

select
    MEMBER_DK as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_MEMBER
where MEMBER_DK is not null
group by MEMBER_DK
having count(*) > 1


