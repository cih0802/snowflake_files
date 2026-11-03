"""O261 · SV COMMENT 「실제값 N종」 라이브 대조 (읽기 전용 · O258-A-2 ②).
판정 = COMMENT 의 N ↔ base 테이블 DISTINCT(NULL 제외) 수. 결과는 tmp/o261/enum_check.csv.
"""
import sys, re, csv
sys.path.insert(0, '/workspace/scripts')
import sfconn

N_PAT = re.compile(r'실제값\s*([0-9]+)\s*종')
COL_PAT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)$')

cn = sfconn.conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
svs = []
for sch in ('SERVING', 'MSTR'):
    cur.execute(f'SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.{sch}')
    ni = [c[0] for c in cur.description].index('name')
    svs += [(sch, r[ni]) for r in cur.fetchall()]

rows = []
for sch, sv in svs:
    cur.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.{sch}.{sv}')
    cols = [c[0].lower() for c in cur.description]
    data = [dict(zip(cols, r)) for r in cur.fetchall()]
    base = {}
    dims = {}
    for d in data:
        kind, name, prop, val = d['object_kind'], d['object_name'], d['property'], d['property_value']
        if kind == 'TABLE':
            base.setdefault(name, {})[prop] = val
        elif kind in ('DIMENSION', 'FACT'):
            dims.setdefault((d['parent_entity'], name), {})[prop] = val
    for (tbl, dname), p in dims.items():
        cm = p.get('COMMENT') or ''
        m = N_PAT.search(cm)
        if not m:
            continue
        b = base.get(tbl, {})
        fq = '.'.join(x for x in (b.get('BASE_TABLE_DATABASE_NAME'), b.get('BASE_TABLE_SCHEMA_NAME'),
                                  b.get('BASE_TABLE_NAME')) if x)
        expr = (p.get('EXPRESSION') or '').strip()
        cm_ = COL_PAT.match(expr)
        live = ''
        verdict = 'SKIP_EXPR'
        if cm_ and fq.count('.') == 2:
            try:
                cur.execute(f'SELECT COUNT(DISTINCT "{cm_.group(1).upper()}") FROM {fq}')
                live = cur.fetchone()[0]
                verdict = 'OK' if int(live) == int(m.group(1)) else 'MISMATCH'
            except Exception as e:
                verdict = 'ERR:' + str(e)[:60]
        rows.append([sch, sv, tbl, dname, expr, fq, m.group(1), live, verdict])
cn.close()

with open('/workspace/tmp/o261/enum_check.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['schema', 'sv', 'logical_table', 'dimension', 'expr', 'base_table', 'comment_n', 'live_n', 'verdict'])
    w.writerows(rows)

from collections import Counter
c = Counter(r[-1].split(':')[0] for r in rows)
print('TOTAL', len(rows), dict(c))
for r in rows:
    if r[-1] != 'OK':
        print(r[1], r[3], 'comment', r[6], 'live', r[7], r[-1])
