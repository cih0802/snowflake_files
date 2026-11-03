import io, sys
sys.path.insert(0,'scripts'); from sfconn import conn
def stmt(path, head):
    L=io.open(path,encoding='utf-8').read().splitlines()
    s=next(i for i,l in enumerate(L) if l.startswith(head)); e=next(i for i in range(s,len(L)) if L[i].rstrip().endswith(';'))
    return '\n'.join(L[s:e+1]).rstrip().rstrip(';')
v=stmt('05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql','CREATE OR REPLACE VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V')
sv=stmt('05_SV-Agent_ai/22_ML_SV_DDL.sql','CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION')
c=conn().cursor(); c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
c.execute(v.replace('GN_DW.SERVING.ML_ONCE_CONVERSION_V','GN_DW.SERVING.ML_ONCE_CONVERSION_V__O186_TMP',1))
c.execute('SELECT COUNT(*), COUNT(DISTINCT ONCE_MBER_NO) FROM GN_DW.SERVING.ML_ONCE_CONVERSION_V__O186_TMP'); print('tmp view rows/members', c.fetchone())
c.execute('DROP VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V__O186_TMP')
c.execute(v)
for r in ('GN_DW_ANALYST','GN_DW_VIEWER','GN_DW_SERVICE'): c.execute(f'GRANT SELECT ON VIEW GN_DW.SERVING.ML_ONCE_CONVERSION_V TO ROLE {r}')
c.execute(sv.replace('GN_DW.SERVING.SV_ML_ONCE_CONVERSION','GN_DW.SERVING.SV_ML_ONCE_CONVERSION__O186_TMP',1)); c.execute('DROP SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION__O186_TMP'); print('sv compile PASS')
c.execute(sv); print('live done')
