# O258 · dbt 모델 한글 리터럴 추출 (읽기 전용 · 증거 생성)
import os, re, io, csv
ROOT = '/workspace/10_dbt_pipeline/models'
OUT = '/workspace/tmp/o258/literals_dbt.csv'
LIT = re.compile(r"'([^']*[가-힣][^']*)'")
# 비교 대상 컬럼 = 리터럴 앞 가장 가까운 식별자
CMP = re.compile(r"([A-Za-z_][A-Za-z0-9_\.]*)\s*(?:=|<>|!=|\bNOT\s+IN\b|\bIN\b|\bLIKE\b|\bILIKE\b)\s*\(?\s*'[^']*[가-힣]", re.I)
REF = re.compile(r"ref\(\s*'([^']+)'\s*\)")
SRC = re.compile(r"source\(\s*'([^']+)'\s*,\s*'([^']+)'\s*\)")


def strip_comments(t):
    t = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), t, flags=re.S)
    t = re.sub(r'\{#.*?#\}', lambda m: '\n' * m.group(0).count('\n'), t, flags=re.S)
    return '\n'.join(l.split('--')[0] for l in t.split('\n'))


rows = []
for dp, dn, fn in os.walk(ROOT):
    for f in sorted(fn):
        if not f.endswith('.sql'):
            continue
        p = os.path.join(dp, f)
        rel = os.path.relpath(p, ROOT)
        raw = io.open(p, encoding='utf-8').read()
        body = strip_comments(raw)
        refs = ';'.join(sorted(set(REF.findall(body))))
        srcs = ';'.join(sorted(set('%s.%s' % s for s in SRC.findall(body))))
        lines = body.split('\n')
        for i, l in enumerate(lines, 1):
            lits = LIT.findall(l)
            if not lits:
                continue
            # 출력 라벨(THEN/ELSE/AS)만 있는 줄은 ctx=OUTPUT
            m = CMP.search(l)
            if m:
                ctx, col = 'FILTER', m.group(1).split('.')[-1].upper()
            elif re.search(r"\bWHEN\b", l, re.I):
                ctx, col = 'WHEN', ''
            else:
                ctx, col = 'OUTPUT', ''
            rows.append([rel, i, ctx, col, '|'.join(lits), refs, srcs, l.strip()[:300]])
with io.open(OUT, 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['file', 'line', 'ctx', 'column', 'literals', 'refs', 'sources', 'text'])
    w.writerows(rows)
from collections import Counter
print('rows', len(rows), Counter(r[2] for r in rows))
