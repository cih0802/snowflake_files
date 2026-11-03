# O208 X2 — 5차 개선 기준선(현행 3종 · 변경 전) · 문항 = 12_agent개선과제/06_O208_문항코퍼스.csv
# 쌍 = (문항, 정답 Agent) + (문항, 현업 예상 Agent) · 원문 = tmp/o208_baseline/<문항ID>__<AGENT>.json
# 사용: python3 tmp/o208_baseline.py [--only Q01,Q02] [--judge]
# Co-authored with CoCo
import csv, json, os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
SRC = '/workspace/12_agent개선과제/06_O208_문항코퍼스.csv'
OUT = '/workspace/tmp/o208_baseline'; os.makedirs(OUT, exist_ok=True)
ROWS = list(csv.DictReader(open(SRC, encoding='utf-8')))


def pairs():
    out = []
    for r in ROWS:
        for a in (r['정답 Agent(현행)'].split('(')[0], r['현업 예상 Agent']):
            if (r['문항ID'], a) not in [(x[0], x[1]) for x in out]:
                out.append((r['문항ID'], a, r['질문']))
    return out


def run(c):
    k, agent, q = c
    path = f'{OUT}/{k}__{agent}.json'
    if os.path.exists(path):
        return k, agent, 'skip'
    try:
        cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
        body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + agent, body))
        open(path, 'w', encoding='utf-8').write(cur.fetchone()[0])
        return k, agent, 'ok'
    except Exception as e:
        return k, agent, 'ERR ' + str(e)[:200]


def tools(d):
    out = []

    def walk(x):
        if isinstance(x, dict):
            v = x.get('name')
            if isinstance(v, str) and v.startswith('analyst_'):
                out.append(v)
            for y in x.values():
                walk(y)
        elif isinstance(x, list):
            for y in x:
                walk(y)
    walk(d.get('content', []))
    return sorted(set(out))


def judge():
    # 🆕 [O208-C] 판정 보강 — ① 무도구 정답(GA 고정 문구 · 계산 전 확인) ② 확인 문구 변이 ③ 영문 사고문 패턴 확대
    import re
    ask = re.compile('(계산할까요|진행할까요|드릴까요|원하시면|알려주시면|확인해야)')
    eng = re.compile(r"\b(I'll|I will|Let me|Found it|There's|Now I)\b")
    by = {r['문항ID']: r for r in ROWS}
    w = csv.writer(open(f'{OUT}/_judge.csv', 'w', encoding='utf-8', newline=''))
    w.writerow(['문항ID', 'Agent', '정답Agent여부', '사용도구', '정답도구사용', '무도구정답', '라우팅판정',
                'MSTR기준', 'GN_DW기준', '계산전확인', '영문사고문'])
    for k, agent, _q in pairs():
        p = f'{OUT}/{k}__{agent}.json'
        if not os.path.exists(p):
            w.writerow([k, agent, '', 'MISSING']); continue
        d = json.load(open(p, encoding='utf-8'))
        t = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
        r = by[k]; ts = tools(d)
        exp = [x.strip() for x in r['정답 도구'].split(';')]
        hit = any(x in ts for x in exp)
        asked = bool(ask.search(t))
        notool = (not ts) and (('IT부서' in t) or (r['계산 전 확인'] == 'Y' and asked) or ('조회되지 않' in t) or ('산출할 수 없' in t))
        w.writerow([k, agent, agent == r['정답 Agent(현행)'].split('(')[0], ' '.join(ts), hit, notool,
                    hit or notool, 'MSTR 기준' in t, 'GN_DW 기준' in t, asked, bool(eng.search(t))])


if __name__ == '__main__':
    P = pairs()
    if '--only' in sys.argv:
        keep = set(sys.argv[sys.argv.index('--only') + 1].split(','))
        P = [p for p in P if p[0] in keep]
    if '--judge' not in sys.argv:
        print('pairs', len(P), flush=True)
        with ThreadPoolExecutor(4) as ex:
            for r in ex.map(run, P):
                print(r, flush=True)
    judge()
