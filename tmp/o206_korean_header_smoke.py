# O206 — 한글 표 헤더 스모크: Agent 응답의 마크다운 표 헤더 · 생성 SQL 별칭에 영문 식별자가 남는지 판정
# 사용: python3 tmp/o206_korean_header_smoke.py  (원문 = tmp/o206_smoke/*.json)
# Co-authored with CoCo
import json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

OUT = '/workspace/tmp/o206_smoke'
os.makedirs(OUT, exist_ok=True)
CASES = [
    ('AGENT_MEMBER', 'M1', '2025년 월별 납부율과 미납비중 추이를 보여줘'),
    ('AGENT_MEMBER', 'M2', '2026년 1~6월 개발구분별 개발건수와 고유 회원수를 보여줘'),
    ('AGENT_EXECUTIVE', 'E1', '연도별 편성예산과 집행예산, 집행율을 보여줘'),
    ('AGENT_EXECUTIVE', 'E2', '2026년 매체별 광고비와 개발단가를 보여줘'),
    ('AGENT_MARKETING', 'K1', '2026년 캠페인카테고리별 12개월 이탈률과 획득 회원수를 비교해줘'),
    ('AGENT_MARKETING', 'K2', '2026년 부서별 월 개발 목표와 실적, 달성율을 보여줘'),
    ('AGENT_MSTR', 'S1', '2026년 7월 MSTR 기준 부서별 개발 건과 명을 보여줘'),
    ('AGENT_MSTR', 'S2', '2026년 1~9월 월별 MSTR 개발(건) 추이를 보여줘'),
]
ENG = re.compile(r'\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\b|\b[a-z]+_[a-z0-9_]+\b')


def run(case):
    agent, key, q = case
    cur = conn().cursor()
    cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
    body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    try:
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', (f'GN_DW.SERVING.{agent}', body))
        raw = cur.fetchone()[0]
    except Exception as e:
        raw = json.dumps({'error': str(e)[:500]}, ensure_ascii=False)
    open(f'{OUT}/{key}.json', 'w', encoding='utf-8').write(raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False))
    return key, agent, q, raw


def judge(raw):
    try:
        d = json.loads(raw)
    except Exception:
        return 'PARSE_FAIL', [], [], ''
    if 'error' in d:
        return 'ERROR', [], [], d['error'][:200]
    texts, sqls = [], []
    def walk(x):
        if isinstance(x, dict):
            if x.get('type') == 'text' and isinstance(x.get('text'), str):
                texts.append(x['text'])
            for k, v in x.items():
                if k == 'sql' and isinstance(v, str):
                    sqls.append(v)
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)
    walk(d)
    final = texts[-1] if texts else ''
    headers = [l for l in final.splitlines() if l.strip().startswith('|') and not re.match(r'^\|[\s\-:|]+\|$', l.strip())]
    # 표마다 첫 행 = 헤더 (구분선 바로 위)
    lines = final.splitlines(); hdr = []
    for i, l in enumerate(lines[1:], 1):
        if re.match(r'^\s*\|[\s\-:|]+\|\s*$', l):
            hdr.append(lines[i - 1])
    bad_hdr = sorted({t for h in hdr for t in ENG.findall(h)})
    bad_sql = []
    for s in sqls:
        for a in re.findall(r'\bAS\s+("?)([^\s,()"]+|[^"]+)\1', s, re.I):
            name = a[1]
            if a[0] == '' and re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name) and not name.startswith('__'):
                bad_sql.append(name)
    verdict = 'PASS' if hdr and not bad_hdr else ('NO_TABLE' if not hdr else 'FAIL')
    return verdict, bad_hdr, sorted(set(bad_sql)), (hdr[0][:160] if hdr else final[:160])


with ThreadPoolExecutor(4) as ex:
    res = list(ex.map(run, CASES))
for key, agent, q, raw in sorted(res):
    v, bh, bs, sample = judge(raw)
    print(f'{key} {agent:16} {v:9} 헤더영문={bh} SQL영문별칭={bs[:6]}')
    print(f'    헤더예: {sample}')
