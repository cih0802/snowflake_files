import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
p = '/workspace/05_SV-Agent_ai/05_3_SV_DDL_MEMBER_COHORT.sql'
s = io.open(p, encoding='utf-8').read()
a = s.index('\nCREATE OR ALTER SEMANTIC VIEW') + 1
b = s.index(';\n', s.index("AI_SQL_GENERATION", a))
ddl = s[a:b]
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
c.execute(ddl)
print(c.fetchall())
c.execute("SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_COHORT METRICS TOTAL_ACQ_MEMBERS)")
print('smoke', c.fetchall())
c.execute("DESCRIBE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT")
rows = [r for r in c.fetchall() if r[3] == 'CAMPAIGN_NAME' and r[2] == 'COMMENT' or (len(r) > 4 and 'CAMPAIGN_NAME' == r[1] and r[3] == 'COMMENT')]
for r in c.execute("DESCRIBE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT").fetchall():
    if 'CAMPAIGN_NAME' in str(r[1]) and r[3] == 'COMMENT':
        print(r[1], str(r[4])[-120:])
