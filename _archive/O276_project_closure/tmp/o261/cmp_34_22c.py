import re, sys
exec(open('/workspace/tmp/o261/cmp_34_22.py', encoding='utf-8').read().split("a = svs(")[0])
a = svs('/workspace/05_SV-Agent_ai/34_DEPLOY_SV_ML_FALLBACK_NOTE.sql')
b = svs('/workspace/05_SV-Agent_ai/22_ML_SV_DDL.sql')
b.update(svs('/workspace/05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql'))


def norm(t):
    t = re.sub(r'(?i)create\s+or\s+(alter|replace)', 'create', t)
    t = re.sub(r'(?i)\b(with\s+synonyms)\s*=\s*', r'\1 ', t)
    t = re.sub(r'(?i)\b(comment)\s*=\s*', r'\1=', t)
    t = re.sub(r'\s+', '', t)
    t = re.sub(r'(?i)references(\w+)\(stdr_mt,mber_no\)', r'references\1', t)
    # 인용 문자열 밖만 소문자화
    parts = re.split(r"('(?:[^']|'')*')", t)
    return ''.join(p if i % 2 else p.lower() for i, p in enumerate(parts))


for k in a:
    x, y = norm(a[k]), norm(b[k])
    if x == y:
        print(k, 'IDENTICAL')
        continue
    i = next((i for i, (p, q) in enumerate(zip(x, y)) if p != q), min(len(x), len(y)))
    print(k, 'DIFF at', i, len(x), len(y))
    print('  34:', x[max(0, i - 60):i + 120])
    print('  22:', y[max(0, i - 60):i + 120])
