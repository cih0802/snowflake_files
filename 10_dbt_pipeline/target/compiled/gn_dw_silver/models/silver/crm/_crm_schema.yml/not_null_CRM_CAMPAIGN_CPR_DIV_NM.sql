
    
    



select CPR_DIV_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where CPR_DIV_CD IS NOT NULL) dbt_subquery
where CPR_DIV_NM is null


