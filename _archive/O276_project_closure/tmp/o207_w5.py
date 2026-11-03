# O207 W5 — 4차 개선 재측정(개발 문항 · 라우팅 = MSTR 도구 사용 여부) · 원문 = tmp/o207_w5/
# 기대 도구: MSTR = analyst_mstr_spnsr_dvlp · GN = MSTR 에 없는 축(교차) → GN_DW 도구
# Co-authored with CoCo
import json, os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
OUT = '/workspace/tmp/o207_w5'; os.makedirs(OUT, exist_ok=True)
CASES = [
    ('P1', 'AGENT_EXECUTIVE', 'MSTR', '부서별 연도말 개발 예측치를 보여줘'),
    ('P2', 'AGENT_EXECUTIVE', 'MSTR', '후원사업별 연도말 개발 예측치를 보여줘'),
    ('P3', 'AGENT_EXECUTIVE', 'MSTR', '연도말 개발 예측치를 보여줘'),
    ('P1M', 'AGENT_MEMBER', 'MSTR', '부서별 연도말 개발 예측치를 보여줘'),
    ('K2', 'AGENT_MARKETING', 'MSTR', '연말 신규회원개발건수 변화 예측'),
    ('D1', 'AGENT_MEMBER', 'MSTR', '2026년 9월 구분_팀별 신규 개발(건)과 개발(명)을 보여줘'),
    ('D2', 'AGENT_MEMBER', 'MSTR', '2026년 9월 신규, 기존으로 구분한 개발건과 개발(명)을 보여줘'),
    ('D3', 'AGENT_MEMBER', 'MSTR', '2026년 9월 후원중단 사유별 중단 건수와 회원수'),
    ('D4', 'AGENT_MARKETING', 'MSTR', '2026년 9월 결제수단별 신규 개발(건)'),
    ('D5', 'AGENT_EXECUTIVE', 'MSTR', '2026년 1월부터 9월까지 월별 신규 개발 목표 대비 달성률'),
    ('X1', 'AGENT_MEMBER', 'GN', '2026년 9월 캠페인카테고리별 신규 개발 건수'),
    ('X2', 'AGENT_MARKETING', 'GN', '2026년 9월 개발인입경로별 신규 개발 건수'),
]


def run(c):
    k, agent, _exp, q = c
    try:
        cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
        body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + agent, body))
        open(f'{OUT}/{k}.json', 'w', encoding='utf-8').write(cur.fetchone()[0])
        return k, 'ok'
    except Exception as e:
        return k, 'ERR ' + str(e)[:200]


if __name__ == '__main__':
    with ThreadPoolExecutor(4) as ex:
        for r in ex.map(run, CASES):
            print(r, flush=True)
