
    
    



select CMPGN_TYPE1_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CMPGN_TYPE1_BSN IS NOT NULL) dbt_subquery
where CMPGN_TYPE1_NM is null


