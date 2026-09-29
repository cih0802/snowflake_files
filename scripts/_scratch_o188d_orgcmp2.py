import csv, json, collections
org = {r['DEPT_ID']: r for r in json.load(open('/tmp/org.json'))}
codes = {r['부서코드'] for r in csv.DictReader(open('/workspace/90_provided_definition/gni_실적부서.csv', encoding='utf-8-sig'))}
use = {k for k, v in org.items() if v['USE_YN'] == 'Y'}
print('USE_Y', len(use), 'csv-use', len(codes - use), 'use-csv', len(use - codes))
def anc_all_use(c):
    seen = set()
    while c and c in org and c not in seen:
        seen.add(c)
        if org[c]['USE_YN'] != 'Y': return False
        c = org[c]['UPPER_DEPT_ID']
    return True
rule = {k for k in use if anc_all_use(k)}
print('rule(use & all ancestors use)', len(rule), 'csv-rule', len(codes - rule), 'rule-csv', len(rule - codes))
extra = sorted(use - codes)[:15]
for k in extra:
    v = org[k]; print('  extra', k, v['DEPT_NM'], 'up', v['UPPER_DEPT_ID'], org.get(v['UPPER_DEPT_ID'], {}).get('USE_YN'))
print(collections.Counter(org[k]['UPPER_DEPT_ID'] in org for k in use - codes))
