# O212 R4 검증 — DESCRIBE AGENT(기본 버전) ↔ 로컬 agent_spec.yaml 4축 대조(지시문 3종 · 도구 집합 · 도구 설명 · 샘플 질문)
# Co-authored with CoCo
import json, sys, yaml
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
cur = conn().cursor()
cur.execute('USE ROLE GN_DW_ADMIN')
bad = 0
for a in ['EXECUTIVE', 'MEMBER', 'MARKETING']:
    loc = yaml.safe_load(open(f'/workspace/cortex_project/agents/AGENT_{a}/agent_spec.yaml', encoding='utf-8'))
    cur.execute(f'DESCRIBE AGENT GN_DW.SERVING.AGENT_{a}')
    cols = [c[0] for c in cur.description]
    row = dict(zip(cols, cur.fetchone()))
    live = json.loads(row['agent_spec'])
    li, ri = loc.get('instructions', {}), live.get('instructions', {})
    ins = sum(li.get(k) != ri.get(k) for k in ('system', 'orchestration', 'response'))
    tn = lambda s: {(t.get('tool_spec', t)['name']): t.get('tool_spec', t).get('description') for t in s.get('tools', [])}
    lt, rt = tn(loc), tn(live)
    tset = set(lt) ^ set(rt)
    tdesc = sum(lt[k] != rt.get(k) for k in lt)
    sq = (li.get('sample_questions') != ri.get('sample_questions'))
    print(a, 'instr_diff', ins, 'toolset_diff', len(tset), 'tooldesc_diff', tdesc, 'sample_diff', int(sq), 'tools', len(rt))
    bad += ins + len(tset) + tdesc + int(sq)
print('TOTAL_DIFF', bad)
