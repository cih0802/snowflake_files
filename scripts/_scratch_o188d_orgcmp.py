import csv, json, collections
org = {r['DEPT_ID']: r for r in json.load(open('/tmp/org.json'))}
rows = list(csv.DictReader(open('/workspace/90_provided_definition/gni_실적부서.csv', encoding='utf-8-sig')))
codes = [r['부서코드'] for r in rows]
print('csv', len(rows), 'distinct', len(set(codes)), 'in_org', sum(c in org for c in codes))
print('missing', [c for c in codes if c not in org])
yn = collections.Counter(org[c]['ACMSLT_DEPT_YN'] for c in codes if c in org)
use = collections.Counter(org[c]['USE_YN'] for c in codes if c in org)
print('csv ACMSLT_YN', yn, 'USE_YN', use)
allY = {k for k, v in org.items() if v['ACMSLT_DEPT_YN'] == 'Y'}
allYU = {k for k in allY if org[k]['USE_YN'] == 'Y'}
print('org Y', len(allY), 'Y&use', len(allYU), 'csv-Y', len(set(codes) - allY), 'Y-csv', len(allY - set(codes)), 'YU-csv', len(allYU - set(codes)))
def path(c, key):
    p, seen = [], set()
    while c and c in org and c not in seen:
        seen.add(c); p.append(org[c]['DEPT_NM']); c = org[c][key]
    return p[::-1]
for key in ('ACMSLT_UPPER_DEPT_ID', 'UPPER_DEPT_ID'):
    ok = 0; bad = []
    for r in rows:
        c = r['부서코드']
        if c not in org: continue
        p = path(c, key)
        exp = r['부서 경로']
        # CSV path omits corporation root (1st level)
        got = ' > '.join(p[1:])
        if got == exp: ok += 1
        else: bad.append((c, exp, got))
    print(key, 'match', ok, 'bad', len(bad)); [print('  ', b) for b in bad[:6]]
nm = sum(org[r['부서코드']]['DEPT_NM'] == r['부서명'] for r in rows if r['부서코드'] in org)
print('name match', nm)
