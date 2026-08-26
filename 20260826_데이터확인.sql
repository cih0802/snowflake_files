-- 멤버 마스터 부재
select MBER_NO from gn_dw.bronze_crm.SND_MEMBER_LIST
MINUS
select MBER_NO from gn_dw.bronze_crm.TM_MM_FDRM_MBER_INFO
MINUS
select ONCE_MBER_NO from gn_dw.bronze_crm.TM_MM_ONCE_MBER_INFO;


select distinct MK_UTM from gn_dw.bronze_crm.TM_CM_MKTNG_UTM
minus
select distinct MKTG_UTM from gn_dw.bronze_crm.TM_CM_CMPGN_MNG;

select distinct MKTG_UTM from gn_dw.bronze_crm.TM_CM_CMPGN_MNG
minus
select distinct MK_UTM from gn_dw.bronze_crm.TM_CM_MKTNG_UTM;

