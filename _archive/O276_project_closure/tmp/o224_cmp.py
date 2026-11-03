# O224 — eval run 쌍 비교(같은 데이터셋 원본 표 · 문항별 4지표 · 평균)
# 사용: python3 tmp/o224_cmp.py <agent> <old_tag> <new_tag> [DS=V3]
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

k, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
ds = sys.argv[4] if len(sys.argv) > 4 else 'V3'
agent = {'executive': 'AGENT_EXECUTIVE', 'member': 'AGENT_MEMBER', 'marketing': 'AGENT_MARKETING'}[k]
M = ('answer_correctness', 'logical_consistency', 'tool_selection_accuracy', 'tool_execution_accuracy')
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
c.execute(f"""
WITH r AS (
  SELECT 'old' v, INPUT, METRIC_NAME, EVAL_AGG_SCORE s FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'GN_DW','SERVING','{agent}','CORTEX AGENT','o224_{k}_{old}'))
  UNION ALL
  SELECT 'new', INPUT, METRIC_NAME, EVAL_AGG_SCORE FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'GN_DW','SERVING','{agent}','CORTEX AGENT','o224_{k}_{new}')))
SELECT e.QUESTION_ID, r.METRIC_NAME, AVG(IFF(v='old', s, NULL)), AVG(IFF(v='new', s, NULL))
FROM r JOIN GN_DW.SERVING.EVAL_O224_{agent}_{ds} e ON e.INPUT_QUERY = r.INPUT
GROUP BY 1, 2 ORDER BY 1, 2""")
rows = c.fetchall()
for m in M:
    rs = [x for x in rows if x[1] == m]
    ao = sum(x[2] or 0 for x in rs) / max(len(rs), 1)
    an = sum(x[3] or 0 for x in rs) / max(len(rs), 1)
    miss = sum(1 for x in rs if x[2] is None or x[3] is None)
    print(f'{agent} {m}: {old} {ao:.4f} → {new} {an:.4f} (n={len(rs)} · 미채점 {miss})')
print('--- 문항별 AC·TS 변화(|Δ|≥0.3)')
q = {}
for qid, m, o, n in rows:
    q.setdefault(qid, {})[m] = (o, n)
for qid in sorted(q):
    ac, ts = q[qid].get('answer_correctness', (None, None)), q[qid].get('tool_selection_accuracy', (None, None))
    if any(a is not None and b is not None and abs(a - b) >= 0.3 for a, b in (ac, ts)):
        print(f'   {qid}: AC {ac[0]} → {ac[1]} · TS {ts[0]} → {ts[1]}')
