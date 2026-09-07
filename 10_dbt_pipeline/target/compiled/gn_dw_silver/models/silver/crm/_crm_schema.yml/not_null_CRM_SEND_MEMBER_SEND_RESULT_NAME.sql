
    
    



select SEND_RESULT_NAME
from (select * from GN_DW.SILVER.CRM_SEND_MEMBER where SEND_RESULT_CD is not null) dbt_subquery
where SEND_RESULT_NAME is null


