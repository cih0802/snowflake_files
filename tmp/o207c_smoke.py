# O207-C — AGENT_MSTR 은퇴 전 대체 검증 + 미정의 지표 확인 규칙 + 답변 품질 · 원문 = tmp/o207c_smoke/
# 기대: M* = MSTR 도구 · Q* = 계산 전 확인(「계산할까요」) · X1 = GN_DW 도구 + 「GN_DW 기준」 · D5 = 영문 사고문 없음
# Co-authored with CoCo
import json, os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
OUT = '/workspace/tmp/o207c_smoke'; os.makedirs(OUT, exist_ok=True)
CASES = [
    ('M1', 'AGENT_MEMBER', '2026년 9월 MSTR 기준 본부/본부 외 그룹별 개발구분별 개발(건)을 보여줘'),
    ('M2', 'AGENT_EXECUTIVE', '2026년 9월 MSTR 기준 신규, 기존으로 구분한 개발건과 개발(명)을 보여줘'),
    ('M3', 'AGENT_MARKETING', 'MSTR 기준 상위캠페인별 개발(건) 상위 10개를 보여줘'),
    ('Q5', 'AGENT_MEMBER', '2026년 추경 회비예측을 보여줘'),
    ('Q6', 'AGENT_MEMBER', '회비 시나리오별(낙관·기본·비관) 2026년 연말 회비 예측을 보여줘'),
    ('X1', 'AGENT_MEMBER', '2026년 9월 캠페인카테고리별 신규 개발 건수'),
    ('D5', 'AGENT_EXECUTIVE', '2026년 1월부터 9월까지 월별 신규 개발 목표 대비 달성률'),
]


def run(c):
    k, agent, q = c
    try:
        cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
        body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + agent, body))
        open(f'{OUT}/{k}.json', 'w', encoding='utf-8').write(cur.fetchone()[0])
        return k, 'ok'
    except Exception as e:
        return k, 'ERR ' + str(e)[:200]


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


if __name__ == '__main__':
    if '--judge' not in sys.argv:
        with ThreadPoolExecutor(4) as ex:
            for r in ex.map(run, CASES):
                print(r, flush=True)
    for k, agent, q in CASES:
        d = json.load(open(f'{OUT}/{k}.json', encoding='utf-8'))
        t = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
        eng = any(w in t for w in ("Let me", "There's", "I'll", "I will"))
        print(k, tools(d), '계산할까요=%s' % ('계산할까요' in t), 'MSTR기준=%s' % ('MSTR 기준' in t),
              'GN_DW기준=%s' % ('GN_DW 기준' in t), '영문사고문=%s' % eng)
