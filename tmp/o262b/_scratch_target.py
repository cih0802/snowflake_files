import io,os,re,json
M='/workspace/10_dbt_pipeline/models'
def files(sub):
    for dp,dn,fn in os.walk(os.path.join(M,sub)):
        for f in fn:
            if f.endswith('.sql'): yield os.path.join(dp,f)
silver={os.path.basename(p)[:-4]:io.open(p,encoding='utf-8').read() for p in files('silver')}
gold={os.path.basename(p)[:-4]:io.open(p,encoding='utf-8').read() for p in files('gold')}
cand=[('DGT_AD_CMPGN_DTLS','CMPGN_TYPE1_BSN_NM'),('DGT_AD_CMPGN_DTLS','CMPGN_TYPE2_BSN_NM'),('REBRDC_AD_CMPGN_DTLS','CHNNL_NM'),('VIDEO_AD_CMPGN_DTLS','CMPGN_TY_NM'),
('SND_MEMBER_LIST','SPNSR_NM'),('SND_MEMBER_LIST','FRST_SPNSR'),('SND_MEMBER_LIST','CHILD_DTL_NM'),('SND_MEMBER_LIST','NATION_NM'),('SND_MEMBER_LIST','BPLC_KOR_NM'),('SND_MEMBER_LIST','NEW_CHILD_PROJECT_COUNTRY'),('SND_MEMBER_LIST','SPNSR_CD'),('SND_MEMBER_LIST','GENDER'),
('SND_REQ_MST','ALT_SMS_YN'),('TD_MS_CRMN_PRTCPNT','RQST_PATH_CD'),('TM_CM_MBER_DVLP_GOAL_DIV','TEAM_NM'),('TM_CM_MBER_DVLP_GOAL_DIV','SPNSR_BSNS_DIV_NM'),
('TM_CM_SCHDUL_MNG','SCHDUL_CD'),('TM_CM_SPNSR_BSNS_INFO','DNTN_TY_CD'),('TM_MM_FDRM_MBER_INFO','PSTMTR_RECPTN_CD'),('TM_MM_FDRM_MBER_INFO','EMAIL_RECPTN_CD'),
('TM_MM_ONCE_MBER_INFO','PSTMTR_RECPTN_YN'),('TM_MM_ONCE_MBER_INFO','EMAIL_RECPTN_YN'),('TM_MS_CRMN','CRMN_DIV_CD'),('TM_PM_MBRFEE_ACMSLT','TOGETH_WTDRW_YN'),
('EXPENSE_RESOLUTION','BDGT_ITEM_NM'),('TM_MM_FDRM_MBER_SPNSR_DSCNTC','REGIST_DEPT_CD'),('TM_MM_ONCE_MBER_INFO','REGIST_DEPT_CD')]
res=[]
for t,c in cand:
    rx=re.compile(r'(?<![A-Za-z0-9_])'+c+r'(?![A-Za-z0-9_])')
    sm=[n for n,s in silver.items() if t in s and rx.search(s)]
    gm=sorted({g for g,s in gold.items() for n in sm if "ref('%s')"%n in s})
    res.append((t,c,sm,gm))
    print(t,c,'| SILVER',sm,'| GOLD',gm)
json.dump(res,io.open('/workspace/tmp/o262b/d_targets.json','w',encoding='utf-8'),ensure_ascii=False)
