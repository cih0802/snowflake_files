import csv, os, re, sys
from collections import Counter, defaultdict
sys.path.insert(0, os.path.dirname(__file__))
DATE = re.compile(r'(?<!\d)(20\d{2})[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12]\d|3[01])(?!\d)')
FROZEN = re.compile(r'(^|/)(_archive|_backup_[^/]*|[^/]*_조각|__pycache__|target|logs)(/|$)')
r = list(csv.DictReader(open('/workspace/tmp/restructure/mm_v2_files.csv', encoding='utf-8-sig')))
print(Counter(x['action'] for x in r))
dated = []
for x in r:
    p = x['old_path']
    fn = p.rsplit('/', 1)[-1]
    m = DATE.search(fn)
    if m and int(''.join(m.groups())) < 20261001:
        dated.append((p, bool(FROZEN.search(p)), x['action']))
print('dated<cutoff', len(dated), 'frozen', sum(1 for d in dated if d[1]))
for p, fz, a in dated:
    if not fz:
        print(a, p)
