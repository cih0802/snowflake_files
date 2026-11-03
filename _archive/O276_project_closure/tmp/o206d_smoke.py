# O206-D — AGENT_MSTR 스모크(현업 질문 재현) · 원문 = tmp/o206d_smoke/
# Co-authored with CoCo
import json, os, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
OUT = '/workspace/tmp/o206d_smoke'; os.makedirs(OUT, exist_ok=True)
CASES = [('M1', '2026년 9월 MSTR 기준 본부/본부 외 그룹별 개발구분별 개발(건)을 보여줘'),
         ('M2', '2026년 9월 MSTR 기준 신규, 기존으로 구분한 개발건과 개발(명)을 보여줘')]


def run(c):
    k, q = c
    cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
    body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.AGENT_MSTR', body))
    open(f'{OUT}/{k}.json', 'w', encoding='utf-8').write(cur.fetchone()[0])
    return k


with ThreadPoolExecutor(2) as ex:
    print(list(ex.map(run, CASES)))
