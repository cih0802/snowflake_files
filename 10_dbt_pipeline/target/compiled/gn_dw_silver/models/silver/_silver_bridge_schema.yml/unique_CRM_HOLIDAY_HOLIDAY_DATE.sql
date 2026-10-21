
    
    

select
    HOLIDAY_DATE as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_HOLIDAY
where HOLIDAY_DATE is not null
group by HOLIDAY_DATE
having count(*) > 1


