"""O261 · SV COMMENT 값 목록 신규값 탐지(종 수 표기 폐지 후 대조 도구).
판정 = COMMENT 의 ''값'' 목록이 라이브 DISTINCT 의 MIN_COVER 이상을 덮는 차원에서, 목록에 없는 라이브 값 = NEW.
추가로 COMMENT 에 「실제값 N종」 잔존 = STALE_COUNT.  결과 = tmp/o261/enum_newvalue.csv
"""
import sys, re, csv
sys.path.insert(0, '/workspace/scripts')
import sfconn

MAX_LIVE, MIN_COVER = 60, 0.5
N_PAT = re.compile(r'실제값\s*[0-9]+\s*종')
VAL_PAT = re.compile(r"''((?:[^']|'''')*?)''|'((?:[^'])*?)'")
COL_PAT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)$')

cn = sfconn.conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
svs = []
for sch in ('SERVING', 'MSTR'):
    cur.execute(f'SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.{sch}')
    ni = [c[0] for c in cur.description].index('name')
    svs += [(sch, r[ni]) for r in cur.fetchall()]

rows, stale, checked = [], 0, 0
for sch, sv in svs:
    cur.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.{sch}.{sv}')
    cols = [c[0].lower() for c in cur.description]
    base, dims = {}, {}
    for d in (dict(zip(cols, r)) for r in cur.fetchall()):
        if d['object_kind'] == 'TABLE':
            base.setdefault(d['object_name'], {})[d['property']] = d['property_value']
        elif d['object_kind'] == 'DIMENSION':
            dims.setdefault((d['parent_entity'], d['object_name']), {})[d['property']] = d['property_value']
    for (tbl, dname), p in dims.items():
        cm = p.get('COMMENT') or ''
        if N_PAT.search(cm):
            stale += 1
            rows.append([sv, dname, 'STALE_COUNT', ''])
        listed = [a or b for a, b in VAL_PAT.findall(cm)]
        m = COL_PAT.match((p.get('EXPRESSION') or '').strip())
        b = base.get(tbl, {})
        fq = '.'.join(x for x in (b.get('BASE_TABLE_DATABASE_NAME'), b.get('BASE_TABLE_SCHEMA_NAME'), b.get('BASE_TABLE_NAME')) if x)
        if not (listed and m and fq.count('.') == 2):
            continue
        col = m.group(1).upper()
        cur.execute(f'SELECT COUNT(DISTINCT "{col}") FROM {fq}')
        if cur.fetchone()[0] > MAX_LIVE:
            continue
        cur.execute(f'SELECT DISTINCT "{col}"::VARCHAR FROM {fq} WHERE "{col}" IS NOT NULL')
        vals = [r[0] for r in cur.fetchall()]
        if not vals or sum(v in listed for v in vals) / len(vals) < MIN_COVER:
            continue
        checked += 1
        new = [v for v in vals if v not in listed]
        if new:
            rows.append([sv, dname, 'NEW', '|'.join(sorted(new))])
cn.close()

with open('/workspace/tmp/o261/enum_newvalue.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f); w.writerow(['sv', 'dimension', 'kind', 'values']); w.writerows(rows)
print('SV', len(svs), '· 목록 대조 차원', checked, '· STALE_COUNT', stale, '· NEW', sum(r[2] == 'NEW' for r in rows))
for r in rows:
    print(*r)
