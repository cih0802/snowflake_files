import csv
from collections import defaultdict
p = '/workspace/30_output_share/O252_폐지부서_귀속_현업리뷰_20261021.csv'
agg = defaultdict(lambda: [0, 0])
for r in csv.DictReader(open(p, encoding='utf-8-sig')):
    k = r['검토우선순위']
    agg[k][0] += 1
    agg[k][1] += int(r['중단_2024'] or 0)
for k, v in sorted(agg.items()):
    print(k, 'depts', v[0], 'stops2024', v[1])
