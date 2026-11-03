# O258 · SV/Agent 서술형 리터럴 전수 → 라벨 사전 대조용 목록
import os, re, io, csv, collections
SV = '/workspace/05_SV-Agent_ai'
Q = re.compile(r"''([^']*[가-힣][^']*)''")
cnt = collections.Counter(); where = collections.defaultdict(set)
for f in sorted(os.listdir(SV)):
    if not (re.match(r'(05_\d|09_)', f) and f.endswith('.sql')):
        continue
    for i, l in enumerate(io.open(os.path.join(SV, f), encoding='utf-8'), 1):
        if l.lstrip().startswith('--'):
            continue
        for v in Q.findall(l):
            v = v.strip()
            if len(v) > 40 or '%' in v:
                continue
            cnt[v] += 1; where[v].add('%s:%d' % (f[:5], i))
with io.open('/workspace/tmp/o258/sv_literals_distinct.csv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh); w.writerow(['literal', 'n', 'sample_loc'])
    for v, n in cnt.most_common():
        w.writerow([v, n, ' '.join(sorted(where[v])[:3])])
print('distinct', len(cnt), 'total', sum(cnt.values()))
print(' | '.join(v for v, _ in cnt.most_common()))
