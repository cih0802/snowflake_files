# O206-C — 재측정 러너(원문 = tmp/o206_round3c/) · 헤더 판정 + 수치 근거 판정
# Co-authored with CoCo
import json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

OUT = '/workspace/tmp/o206_round3c'
os.makedirs(OUT, exist_ok=True)
qs = open('/workspace/tmp/o205_smoke.py', encoding='utf-8').read()
Q = dict(re.findall(r"'(Q[1-4])': '([^']+)'", qs))
ns = {}
exec(open('/workspace/tmp/o206_round3_cases.py', encoding='utf-8').read(), ns)
R = {k: q for _, k, q in ns['CASES']}
CASES = [('AGENT_MEMBER', k, R[k]) for k in ['R03', 'R04', 'R07', 'R09', 'R11']]
CASES += [('AGENT_MEMBER', 'Q3', Q['Q3']), ('AGENT_MEMBER', 'Q4', Q['Q4'])]
CASES += [('AGENT_EXECUTIVE', 'E1', '연도별 편성예산과 집행예산, 집행율을 보여줘'),
          ('AGENT_MARKETING', 'K3', '2026년 월별 광고비와 노출수 추이를 보여줘'),
          ('AGENT_MSTR', 'S1', '2026년 7월 MSTR 기준 부서별 개발 건과 명을 보여줘')]


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
    return key


with ThreadPoolExecutor(4) as ex:
    print(list(ex.map(run, CASES)))
