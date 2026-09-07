
    
    



select *
from (select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION where PARTCPT_CHNNL_CD is not null) dbt_subquery
where PARTCPT_CHNNL_NM is null


