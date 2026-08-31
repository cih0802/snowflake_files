
    
    

select
    MK_CMPGN_CD as unique_field,
    count(*) as n_records

from GN_DW.SILVER.CRM_MARKETING_CAMPAIGN
where MK_CMPGN_CD is not null
group by MK_CMPGN_CD
having count(*) > 1


