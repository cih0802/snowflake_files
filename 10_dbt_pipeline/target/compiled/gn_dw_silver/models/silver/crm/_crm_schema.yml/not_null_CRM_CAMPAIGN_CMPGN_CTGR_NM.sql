
    
    



select CMPGN_CTGR_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMPGN_CTGR_CD IS NOT NULL) dbt_subquery
where CMPGN_CTGR_NM is null


