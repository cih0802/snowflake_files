# O258 · dbt yml accepted_values 정리 (yaml 파싱)
import os, io, yaml, csv, re
ROOT = '/workspace/10_dbt_pipeline'
rows = []


def walk_tests(model, col, tests, f):
    for t in tests or []:
        if isinstance(t, dict) and 'accepted_values' in t:
            a = t['accepted_values'] or {}
            vals = a.get('values') or (a.get('arguments') or {}).get('values') or []
            cfg = a.get('config') or {}
            sev = cfg.get('severity', a.get('severity', 'error'))
            han = any(re.search('[가-힣]', str(v)) for v in vals)
            rows.append([f, model, col, sev, len(vals), int(han), ' · '.join(map(str, vals))[:300]])


for dp, dn, fn in os.walk(os.path.join(ROOT, 'models')):
    for f in fn:
        if not f.endswith('.yml'):
            continue
        p = os.path.join(dp, f)
        d = yaml.safe_load(io.open(p, encoding='utf-8')) or {}
        rel = os.path.relpath(p, ROOT)
        for m in (d.get('models') or []) + [t for s in (d.get('sources') or []) for t in (s.get('tables') or [])]:
            for c in m.get('columns') or []:
                walk_tests(m['name'], c['name'], c.get('tests') or c.get('data_tests'), rel)
with io.open('/workspace/tmp/o258/accepted_values.csv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh); w.writerow(['file', 'model', 'column', 'severity', 'n_values', 'hangul', 'values']); w.writerows(rows)
import collections
print('tests', len(rows), collections.Counter((r[3], r[5]) for r in rows))
for r in rows:
    if r[5]:
        print(r[1], r[2], r[3], '|', r[6][:160])
