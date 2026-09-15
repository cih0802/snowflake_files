
    
    



select MKTG_UTM_NM
from (select * from GN_DW.SILVER.CRM_CAMPAIGN where MKTG_UTM IS NOT NULL) dbt_subquery
where MKTG_UTM_NM is null


