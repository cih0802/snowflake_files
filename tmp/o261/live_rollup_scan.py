import sys, re
sys.path.insert(0, '/workspace/scripts')
import sfconn

cn = sfconn.conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
svs = []
for sch in ('SERVING', 'MSTR'):
    cur.execute(f'SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.{sch}')
    cols = [c[0] for c in cur.description]
    ni = cols.index('name')
    svs += [(sch, r[ni]) for r in cur.fetchall()]
pat = re.compile(r'\b(ROLLUP|GROUPING\s+SETS|CUBE)\b', re.I)
# O259 금지 문구(부정문)는 제외 — J8: 부정문은 정확한 토큰으로 재판정
neg = re.compile(r'(ROLLUP·CUBE·GROUPING SETS 금지|ROLLUP 금지)')
hits = []
for sch, name in svs:
    cur.execute(f"SELECT GET_DDL('SEMANTIC_VIEW', 'GN_DW.{sch}.{name}')")
    ddl = neg.sub('', cur.fetchone()[0] or '')
    n = len(pat.findall(ddl))
    if n:
        hits.append((sch, name, n))
print('SV_TOTAL', len(svs))
print('SV_WITH_ROLLUP', len(hits))
for h in hits:
    print('HIT', h)
cn.close()
