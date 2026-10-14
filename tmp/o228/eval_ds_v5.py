# O228 ⑤ — eval 정답지 MEMBER V5 = V4 + 정답 도구가 있는 문항에 search_biz_definition 을 선행 호출로 추가
# 근거 = 사용자 결정(O228 · 2026-10-14) 「도구 선택 정답에 search_biz_definition 선행 호출을 넣는다」
#   (O227 MEMBER TS 0.48 · TE 0.56 저조 = Agent 가 정의 검색을 먼저 부르는데 정답지에 없다)
# V4 는 기준선이라 건드리지 않는다 · 무도구(되묻기·안내) 문항은 바꾸지 않는다
# 사용: python3 tmp/o228/eval_ds_v5.py dry | apply
# Co-authored with CoCo
import json, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

MODE = sys.argv[1]
assert MODE in ('dry', 'apply')
PRE = 'search_biz_definition'
WHY = 'O228 사용자 결정 = 정의 검색 선행 호출을 정답 도구에 포함(V4 + 선행 1)'
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
c.execute('USE DATABASE GN_DW'); c.execute('USE SCHEMA SERVING')
c.execute('DESCRIBE AGENT GN_DW.SERVING.AGENT_MEMBER')
cols = [d[0] for d in c.description]
live = {t['tool_spec']['name'] for t in json.loads(c.fetchone()[cols.index('agent_spec')])['tools']}
assert PRE in live, 'search_biz_definition 이 라이브 MEMBER 에 없다'
c.execute('SELECT INPUT_QUERY, EXPECTED_OUTPUT::string, QUESTION_ID, TRACK FROM EVAL_O224_AGENT_MEMBER_V4 ORDER BY QUESTION_ID')
new, hit = [], 0
for q, exp, qid, tr in c.fetchall():
    e = json.loads(exp)
    inv = e.get('ground_truth_invocations') or []
    reason = None
    if inv and inv[0].get('tool_name') != PRE:
        e['ground_truth_invocations'] = [{'tool_name': PRE}] + inv
        reason, hit = WHY, hit + 1
    print(qid, [x['tool_name'] for x in e.get('ground_truth_invocations') or []], '변경' if reason else '-')
    new.append((q, json.dumps(e, ensure_ascii=False), qid, tr, reason))
print('rows', len(new), '· 변경', hit)
if MODE == 'apply':
    tbl = 'GN_DW.SERVING.EVAL_O224_AGENT_MEMBER_V5'
    c.execute(f'CREATE TABLE IF NOT EXISTS {tbl} (INPUT_QUERY STRING, EXPECTED_OUTPUT VARIANT, QUESTION_ID STRING, TRACK STRING, REASON STRING)')
    c.execute(f'SELECT COUNT(*) FROM {tbl}')
    if c.fetchone()[0] == 0:
        for r in new:
            c.execute(f'INSERT INTO {tbl} SELECT %s, PARSE_JSON(%s), %s, %s, %s', r)
    c.execute(f'SELECT COUNT(*), COUNT(REASON) FROM {tbl}')
    print(tbl, c.fetchone())
    c.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{tbl}', 'O224_MEMBER_DS_V5', "
              "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'EXPECTED_OUTPUT'))")
    print(str(c.fetchone())[:200])
