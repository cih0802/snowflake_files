import io, sys
sys.path.insert(0,'scripts'); from sfconn import conn
src=io.open('05_SV-Agent_ai/05_6_SV_DDL_BUDGET.sql',encoding='utf-8').read().splitlines()
s=next(i for i,l in enumerate(src) if l.startswith('CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET'))
e=next(i for i in range(s,len(src)) if 'AI_SQL_GENERATION' in src[i] and src[i].rstrip().endswith("';"))
ddl='\n'.join(src[s:e+1]).rstrip().rstrip(';')
c=conn().cursor(); c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
c.execute(ddl.replace('GN_DW.SERVING.SV_BUDGET','GN_DW.SERVING.SV_BUDGET__O186_TMP',1)); c.execute('DROP SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET__O186_TMP'); print('compile PASS')
c.execute(ddl); print('live done')
