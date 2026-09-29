import csv, json
b = {r['DEPT_ID']: r for r in json.load(open('/tmp/b.json'))}
org = {r['DEPT_ID']: r for r in json.load(open('/tmp/org.json'))}
codes = {r['부서코드'] for r in csv.DictReader(open('/workspace/90_provided_definition/gni_실적부서.csv', encoding='utf-8-sig'))}
up = {k: org[k]['UPPER_DEPT_ID'] for k in org}
live = lambda k: b[k]['USE_YN'] == 'Y' and b[k]['L'] not in (None, '9999-12-31')
def anc(c):
    out, s = [], set()
    while c and c in b and c not in s: s.add(c); out.append(c); c = up.get(c)
    return out
r2 = {k for k in b if all(live(a) for a in anc(k))}
kids = {}
for k, p in up.items(): kids.setdefault(p, []).append(k)
r3 = {k for k in r2 if not kids.get(k) or any(c in r2 for c in kids[k])}
print('r3', len(r3), 'csv-r3', sorted(codes - r3), 'r3-csv', sorted(r3 - codes))
print('csv nodes with kids but no live kid:', [k for k in codes if kids.get(k) and not any(c in r2 for c in kids[k])])
