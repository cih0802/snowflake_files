import io, sys
sys.path.insert(0,'scripts'); from sfconn import conn
NEW = "RT(재방송)유형 ← REBRDC.DIV_NM(재송출/방송 · O182 재편 전 RE_BRDC_TY_NM) [REBRDC 전용]. 코어에서 이관"
P='03_top-down_gold/06_DDL.sql'; L=io.open(P,encoding='utf-8').read().split('\n')
assert "REBRDC.RE_BRDC_TY_NM [REBRDC 전용]. 코어에서 이관'" in L[1313]
L[1313]=L[1313].replace("RT(재방송)유형 ← REBRDC.RE_BRDC_TY_NM [REBRDC 전용]. 코어에서 이관", NEW)
io.open(P,'w',encoding='utf-8',newline='').write('\n'.join(L))
W='10_dbt_pipeline/models/gold/wide/_wide_schema.yml'; T=io.open(W,encoding='utf-8').read()
old='RT(재방송)유형 ← REBRDC.RE_BRDC_TY_NM [REBRDC 전용]'; assert T.count(old)==1
io.open(W,'w',encoding='utf-8',newline='').write(T.replace(old,'RT(재방송)유형 ← REBRDC.DIV_NM(재송출/방송 · O182 재편 전 RE_BRDC_TY_NM) [REBRDC 전용]'))
c=conn().cursor(); c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
c.execute(f"ALTER TABLE GN_DW.GOLD.FACT_AD_BROADCAST ALTER COLUMN RT_TYPE COMMENT '{NEW}'"); print('ok')
