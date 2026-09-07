
    
    



select MK_CMPGN_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where MKTG_CMPGN_NM IS NOT NULL) dbt_subquery
where MK_CMPGN_NM is null


