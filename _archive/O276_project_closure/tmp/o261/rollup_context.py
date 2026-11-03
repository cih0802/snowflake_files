import sys, re
sys.path.insert(0, '/workspace/scripts')
import sfconn

cn = sfconn.conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
pat = re.compile(r'\b(ROLLUP|GROUPING\s+SETS|CUBE)\b', re.I)
for name in sys.argv[1:]:
    cur.execute(f"SELECT GET_DDL('SEMANTIC_VIEW', 'GN_DW.SERVING.{name}')")
    ddl = cur.fetchone()[0] or ''
    for m in pat.finditer(ddl):
        s = ddl[max(0, m.start()-120):m.end()+80].replace('\n', ' ')
        print(name, '|', s)
cn.close()
