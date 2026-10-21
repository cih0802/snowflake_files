
    
    

select
    BIZ_TARGET_DK as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_BIZ_TARGET
where BIZ_TARGET_DK is not null
group by BIZ_TARGET_DK
having count(*) > 1


