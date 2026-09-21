
    
    



select MKTG_CHANNEL_NM
from (select * from GN_DW.GOLD.DIM_CAMPAIGN where MKTG_CHANNEL IS NOT NULL) dbt_subquery
where MKTG_CHANNEL_NM is null


