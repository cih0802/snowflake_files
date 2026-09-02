
    
    



select MEMBER_DK
from (select * from GN_DW.SILVER.IDENTITY_MEMBER_XREF where MATCH_METHOD = 'MEMBER_ID_EXACT') dbt_subquery
where MEMBER_DK is null


