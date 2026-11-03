# O258 · SV(05_*) · Agent(09_*) 필터형 리터럴 추출 (읽기 전용)
import os, re, io, csv, collections
SV = '/workspace/05_SV-Agent_ai'
OUT = '/workspace/tmp/o258/literals_sv.csv'
# SQL 문자열 안이므로 따옴표가 '' 로 이스케이프돼 있다
Q = r"''([^']*[가-힣][^']*)''"
P_EQ = re.compile(r"([A-Za-z_][A-Za-z0-9_\.]*)\s*(=|<>|!=|LIKE|ILIKE)\s*" + Q, re.I)
P_IN = re.compile(r"([A-Za-z_][A-Za-z0-9_\.]*)\s+(?:NOT\s+)?IN\s*\(([^)]*''[^)]*)\)", re.I)
rows = []
files = sorted(f for f in os.listdir(SV) if re.match(r'(05_\d|09_)', f) and f.endswith('.sql'))
for f in files:
    for i, l in enumerate(io.open(os.path.join(SV, f), encoding='utf-8'), 1):
        if l.lstrip().startswith('--'):
            continue
        for m in P_EQ.finditer(l):
            rows.append([f, i, m.group(1).split('.')[-1].upper(), m.group(3)])
        for m in P_IN.finditer(l):
            for v in re.findall(Q, m.group(2)):
                rows.append([f, i, m.group(1).split('.')[-1].upper(), v])
with io.open(OUT, 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh); w.writerow(['file', 'line', 'column', 'literal']); w.writerows(rows)
pairs = collections.Counter((r[2], r[3]) for r in rows)
print('rows', len(rows), 'pairs', len(pairs), 'files', len({r[0] for r in rows}))
bycol = collections.defaultdict(set)
for c, v in pairs: bycol[c].add(v)
for c in sorted(bycol, key=lambda c: -len(bycol[c])):
    print(c, '|', ' · '.join(sorted(bycol[c]))[:400])
