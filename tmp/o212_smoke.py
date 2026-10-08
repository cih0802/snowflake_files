# O212 R6 스모크 — 회의 지적 문항(공통브랜드 · 개발인입경로 · 캠페인유형 · 예측 답변 형식) × 3 Agent
# 원문 = tmp/o212_smoke/<ID>__<AGENT>.json · 요약 = tmp/o212_smoke/_summary.csv
# Co-authored with CoCo
import csv, json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts'); sys.path.insert(0, '/workspace/tmp')
import o208_baseline as B
B.OUT = OUT = '/workspace/tmp/' + (sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else 'o212_smoke'); os.makedirs(OUT, exist_ok=True)
Q = [
    ('S1', '26년 8월 공통브랜드 기준으로 가져와줘'),
    ('S2', '26년 8월 개발인입경로별 신규 개발 실적 알려줘'),
    ('S3', '26년 8월 캠페인유형별 개발 실적 보여줘'),
    ('S4', '26년 8월 캠페인카테고리별 개발 실적 보여줘'),
    ('S5', '회원 중단 예측 결과 알려줘'),
]
AG = ['AGENT_EXECUTIVE', 'AGENT_MEMBER', 'AGENT_MARKETING']
P = [(k, a, q) for k, q in Q for a in AG]
if '--judge' not in sys.argv:
    with ThreadPoolExecutor(5) as ex:
        for r in ex.map(B.run, P):
            print(r, flush=True)
eng = re.compile(r"\b(I'll|I will|Let me|Found it|There's|Now I)\b")
w = csv.writer(open(f'{OUT}/_summary.csv', 'w', encoding='utf-8', newline=''))
w.writerow(['ID', 'Agent', '도구', 'SQL축', '요약절', '상세절', '차트', '영문', '본문자수'])
for k, a, q in P:
    p = f'{OUT}/{k}__{a}.json'
    if not os.path.exists(p):
        w.writerow([k, a, 'MISSING']); continue
    raw = open(p, encoding='utf-8').read(); d = json.loads(raw)
    t = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
    ax = [x for x in ('CMMN_BRND', 'BRND_NM', 'CAMPAIGN_BRAND', 'INFLOW_PATH', 'CMPGN_TYPE2', 'BIZ_CASE_TYPE', 'CMPGN_CTGR', 'CAMPAIGN_TYPE') if x in raw]
    w.writerow([k, a, ' '.join(B.tools(d)), ' '.join(ax), '요약' in t[:200], '상세' in t, 'chart' in raw.lower() or 'vega' in raw.lower(),
                bool(eng.search(t)), len(t)])
print('done')
