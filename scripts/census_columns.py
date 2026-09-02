import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '/tmp')
from sfconn import conn, q

SCHEMAS = ['GOLD', 'SILVER', 'SERVING']
OUT = '/tmp/census.json'

cn = conn()
try:
    q("USE WAREHOUSE GN_DW_ANALYTICS_WH", cn)
except Exception:
    pass

cols, rows = q("""
select table_schema, table_name, column_name, data_type, ordinal_position
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema in ('GOLD','SILVER','SERVING')
order by table_schema, table_name, ordinal_position
""", cn)
inv = {}
for s, t, c, dt, op in rows:
    inv.setdefault((s, t), []).append((c, dt))

_, trows = q("""
select table_schema, table_name, table_type from GN_DW.INFORMATION_SCHEMA.TABLES
where table_schema in ('GOLD','SILVER','SERVING')
""", cn)
ttype = {(s, t): ty for s, t, ty in trows}

NUMT = {'NUMBER', 'FLOAT', 'DECIMAL', 'INT', 'INTEGER', 'BIGINT', 'DOUBLE', 'REAL'}

result = {}
if os.path.exists(OUT):
    try:
        result = json.load(open(OUT, 'r', encoding='utf-8'))
    except Exception:
        result = {}

for (s, t), cl in sorted(inv.items()):
    if ttype.get((s, t)) != 'BASE TABLE':
        continue
    key = f'{s}.{t}'
    if key in result:
        print(f'{key}: CACHED (rows={result[key]["rows"]})', flush=True)
        continue
    sel = ['COUNT(*) as "__ROWS"']
    meta = []
    for c, dt in cl:
        qc = f'"{c}"'
        sel.append(f'COUNT({qc}) as "NN__{c}"')
        meta.append((c, dt))
        if dt in NUMT:
            sel.append(f'COUNT_IF({qc} <> 0) as "NZ__{c}"')
        elif dt == 'BOOLEAN':
            sel.append(f'COUNT_IF({qc}) as "NZ__{c}"')
        elif dt in ('TEXT', 'VARCHAR', 'STRING', 'CHAR'):
            sel.append(f'COUNT_IF({qc} IS NOT NULL AND {qc} <> \'\') as "NZ__{c}"')
        else:
            sel.append(f'COUNT({qc}) as "NZ__{c}"')
        sel.append(f'APPROX_COUNT_DISTINCT({qc}) as "DC__{c}"')
    sql = f'select {", ".join(sel)} from GN_DW.{s}."{t}"'
    try:
        hc, hr = q(sql, cn)
        vals = dict(zip(hc, hr[0]))
    except Exception as e:
        print('ERR', s, t, str(e)[:200], flush=True)
        continue
    tot = vals['__ROWS']
    entry = {'rows': tot, 'cols': {}}
    for c, dt in meta:
        entry['cols'][c] = {
            'type': dt,
            'nonnull': vals.get(f'NN__{c}'),
            'nonzero': vals.get(f'NZ__{c}'),
            'ndv': vals.get(f'DC__{c}'),
        }
    result[key] = entry
    print(f'{key}: rows={tot} cols={len(meta)}', flush=True)
    json.dump(result, open(OUT, 'w'), ensure_ascii=False, indent=1, default=str)

json.dump(result, open(OUT, 'w'), ensure_ascii=False, indent=1, default=str)
print('WROTE', OUT)
cn.close()
