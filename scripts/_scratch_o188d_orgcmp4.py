import csv, json, collections
b = {r['DEPT_ID']: r for r in json.load(open('/tmp/b.json'))}
org = {r['DEPT_ID']: r for r in json.load(open('/tmp/org.json'))}
codes = {r['부서코드'] for r in csv.DictReader(open('/workspace/90_provided_definition/gni_실적부서.csv', encoding='utf-8-sig'))}
def anc(c):
    out, s = [], set()
    while c and c in org and c not in s: s.add(c); out.append(c); c = org[c]['UPPER_DEPT_ID']
    return out
allu = {k for k in org if all(org[a]['USE_YN']=='Y' for a in anc(k))}
ex = allu - codes
for f in ('L', 'U', 'STATS_DEPT_LVL'):
    print(f, 'csv', collections.Counter(b[k][f] for k in codes).most_common(5))
    print(f, 'ext', collections.Counter(b[k][f] for k in ex).most_common(5))
