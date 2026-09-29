import csv, json, collections
org = {r['DEPT_ID']: r for r in json.load(open('/tmp/org.json'))}
codes = {r['부서코드'] for r in csv.DictReader(open('/workspace/90_provided_definition/gni_실적부서.csv', encoding='utf-8-sig'))}
used = {r['D'] for r in json.load(open('/tmp/used.json')) if r['D']}
def anc(c):
    out, seen = [], set()
    while c and c in org and c not in seen:
        seen.add(c); out.append(c); c = org[c]['UPPER_DEPT_ID']
    return out
def cmp(name, s):
    print(f'{name:40s} n={len(s):4d} csv-s={len(codes-s):3d} s-csv={len(s-codes):3d}')
use = {k for k, v in org.items() if v['USE_YN'] == 'Y'}
allu = {k for k in use if all(org[a]['USE_YN'] == 'Y' for a in anc(k))}
cmp('used', used)
clos = {a for u in used for a in anc(u)}
cmp('used+ancestors', clos)
cmp('used+anc & allUse', clos & allu)
cmp('allUse & SORT not null', {k for k in allu if org[k]['SORT_ORDR'] is not None})
print('SORT in csv', collections.Counter(org[k]['SORT_ORDR'] is None for k in codes))
print('SORT in extra', collections.Counter(org[k]['SORT_ORDR'] is None for k in allu - codes))
x = sorted(allu - codes, key=lambda k: org[k]['DEPT_NM'])
print([org[k]['DEPT_NM'] for k in x][:40])
