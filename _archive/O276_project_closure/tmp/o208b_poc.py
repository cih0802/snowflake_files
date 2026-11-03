# O208-B X3 — 위임형 가이드 PoC 측정 · 원문 = tmp/o208b_poc/
# Co-authored with CoCo
import json, os, sys, time
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
OUT = '/workspace/tmp/o208b_poc'; os.makedirs(OUT, exist_ok=True)
CASES = [
    ('D4', 'AGENT_EXECUTIVE', '2026년 9월 결제수단별 신규 개발(건)'),
    ('Q28', 'AGENT_MEMBER', '일시 후원자 중 6개월 내 정기 후원자로 전환할 확률이 가장 높은 회원은 누구인가?'),
    ('Q25', 'AGENT_MARKETING', '현재 이탈 위험이 가장 높은 페이지는 어디인가?'),
]


def run(c):
    k, exp, q = c
    cur = conn().cursor(); cur.execute('USE ROLE ACCOUNTADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
    body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    t0 = time.time()
    try:
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.AGENT_GUIDE_POC', body))
        raw = cur.fetchone()[0]
    except Exception as e:
        return k, exp, 'ERR ' + str(e)[:300], round(time.time() - t0, 1)
    sec = round(time.time() - t0, 1)
    open(f'{OUT}/{k}.json', 'w', encoding='utf-8').write(raw)
    d = json.loads(raw)
    calls = []

    def walk(x):
        if isinstance(x, dict):
            if x.get('name') == 'ask_sub_agent' and isinstance(x.get('input'), dict):
                calls.append(x['input'].get('agent_name'))
            for y in x.values():
                walk(y)
        elif isinstance(x, list):
            for y in x:
                walk(y)
    walk(d.get('content', []))
    t = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
    return k, exp, calls, sec, t[:300].replace('\n', ' ')


if __name__ == '__main__':
    with ThreadPoolExecutor(3) as ex:
        for r in ex.map(run, CASES):
            print(r, flush=True)
