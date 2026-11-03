# O209 X4 — AGENT_GUIDE 추천 정확도 · 문항 = 12_agent개선과제/06_O208_문항코퍼스.csv(48)
# 판정 = 추천(교차면 추천 1) Agent == 질문단위_수정안의 Agent · 원문 = tmp/o209_guide/<문항ID>.json
# 사용: python3 tmp/o209_guide.py --create | [--only Q01,Q02] | --judge
# Co-authored with CoCo
import csv, json, os, re, sys, time
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
SRC = '/workspace/12_agent개선과제/06_O208_문항코퍼스.csv'
SPEC = '/workspace/12_agent개선과제/09_O209_AGENT_GUIDE_spec.yaml'
SQL = '/workspace/12_agent개선과제/09_O209_AGENT_GUIDE_create.sql'
OUT = os.environ.get('O209_GUIDE_OUT', '/workspace/tmp/o209_guide'); os.makedirs(OUT, exist_ok=True)
AGENT = 'GN_DW.SERVING.AGENT_GUIDE'
UNIT = {'경영·기획': 'AGENT_EXECUTIVE', '회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
ROWS = list(csv.DictReader(open(SRC, encoding='utf-8')))


def create():
    spec = '\n'.join(l for l in open(SPEC, encoding='utf-8').read().split('\n') if not l.startswith('#'))
    stmts = [s.strip() for s in open(SQL, encoding='utf-8').read().replace('__SPEC__', spec).split(';\n') if s.strip()]
    cur = conn().cursor()
    for s in stmts:
        body = '\n'.join(l for l in s.split('\n') if not l.startswith('--')).strip()
        if body:
            cur.execute(body)
    cur.execute(f'DESCRIBE AGENT {AGENT}')
    print(cur.fetchall()[0][:5])


def run(r):
    k, q = r['문항ID'], r['질문']
    path = f'{OUT}/{k}.json'
    if os.path.exists(path):
        return k, 'skip'
    t0 = time.time()
    try:
        cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
        body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', (AGENT, body))
        raw = cur.fetchone()[0]
    except Exception as e:
        return k, 'ERR ' + str(e)[:200]
    d = json.loads(raw); d['_sec'] = round(time.time() - t0, 1)
    open(path, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False))
    return k, 'ok', d['_sec']


def judge():
    pat = re.compile(r'추천(?:\s*1)?\s*:\s*\**\s*(AGENT_[A-Z]+)')
    allp = re.compile(r'추천(?:\s*\d)?\s*:\s*\**\s*(AGENT_[A-Z]+)')
    w = csv.writer(open(f'{OUT}/_judge.csv', 'w', encoding='utf-8', newline=''))
    w.writerow(['문항ID', '정답Agent(수정안)', '추천', '추천전체', '일치', '교차분리', '형식준수', '지연초', '현업예상Agent'])
    ok = n = 0; by = {}
    for r in ROWS:
        k = r['문항ID']; exp = UNIT[r['질문단위_수정안']]; p = f'{OUT}/{k}.json'
        if not os.path.exists(p):
            w.writerow([k, exp, 'MISSING']); n += 1; continue
        d = json.load(open(p, encoding='utf-8'))
        t = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
        m = pat.search(t); got = m.group(1) if m else ''
        alls = allp.findall(t)
        hit = got == exp; ok += hit; n += 1
        by.setdefault(exp, [0, 0]); by[exp][0] += hit; by[exp][1] += 1
        w.writerow([k, exp, got, ' '.join(alls), hit, len(set(alls)) > 1, bool(m) and '다듬은 질문' in t,
                    d.get('_sec', ''), r['현업 예상 Agent']])
    print(f'정확도 {ok}/{n} = {ok / n:.1%}', {a: f'{v[0]}/{v[1]}' for a, v in by.items()})


if __name__ == '__main__':
    if '--create' in sys.argv:
        create(); sys.exit()
    R = ROWS
    if '--only' in sys.argv:
        keep = set(sys.argv[sys.argv.index('--only') + 1].split(','))
        R = [r for r in R if r['문항ID'] in keep]
    if '--judge' not in sys.argv:
        with ThreadPoolExecutor(4) as ex:
            for x in ex.map(run, R):
                print(x, flush=True)
    judge()
