import csv, json, collections
b = {r['DEPT_ID']: r for r in json.load(open('/tmp/b.json'))}
codes = {r['부서코드'] for r in csv.DictReader(open('/workspace/90_provided_definition/gni_실적부서.csv', encoding='utf-8-sig'))}
live = lambda k: b[k]['USE_YN'] == 'Y' and b[k]['L'] not in (None, '9999-12-31')
def anc(c):
    out, s = [], set()
    while c and c in b and c not in s: s.add(c); out.append(c); c = b[c].get('UP')
    return out
org = {r['DEPT_ID']: r for r in json.load(open('/tmp/org.json'))}
for k in b: b[k]['UP'] = org[k]['UPPER_DEPT_ID'] if k in org else None
r1 = {k for k in b if live(k)}
r2 = {k for k in b if all(live(a) for a in anc(k))}
for n, s in (('self live', r1), ('self+ancestors live', r2)):
    print(n, len(s), 'csv-s', len(codes - s), 's-csv', len(s - codes))
for k in sorted(codes - r2)[:10]: print(' miss', k, b[k]['L'], [ (a,b[a]['L']) for a in anc(k) if not live(a)][:2])
for k in sorted(r2 - codes)[:10]: print(' extra', k, org[k]['DEPT_NM'], b[k]['L'])
