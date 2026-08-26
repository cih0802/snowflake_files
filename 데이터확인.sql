select distinct MK_UTM from gn_dw.bronze_crm.TM_CM_MKTNG_UTM
minus
select distinct MKTG_UTM from gn_dw.bronze_crm.TM_CM_CMPGN_MNG;

select distinct MKTG_UTM from gn_dw.bronze_crm.TM_CM_CMPGN_MNG
minus
select distinct MK_UTM from gn_dw.bronze_crm.TM_CM_MKTNG_UTM;