
    
    



select MKTG_CHANNEL_NM
from (select * from GN_DW.SILVER.CRM_MEMBER_DEV where MKTG_CHANNEL IS NOT NULL) dbt_subquery
where MKTG_CHANNEL_NM is null


