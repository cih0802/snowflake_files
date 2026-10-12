# O216-C — eval 비교 러너(같은 DS V3 · run 쌍 비교 · 문항별 AC/TS)
# 사용: python3 tmp/o216c_eval_cmp.py <old_tag> <new_tag> [agent ...]
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

old, new = sys.argv[1], sys.argv[2]
AG = {'executive': ('AGENT_EXECUTIVE', 'EVAL_O216_AGENT_EXECUTIVE_V3'),
      'member': ('AGENT_MEMBER', 'EVAL_O216_AGENT_MEMBER_V3'),
      'marketing': ('AGENT_MARKETING', 'EVAL_O216_AGENT_MARKETING_V3')}
sel = sys.argv[3:] or list(AG)
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
for k in sel:
    agent, tbl = AG[k]
    q = f"""
    WITH r AS (
      SELECT 'old' v, INPUT, METRIC_NAME, EVAL_AGG_SCORE s FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
        'GN_DW','SERVING','{agent}','CORTEX AGENT','o216_{k}_v3_{old}'))
      UNION ALL
      SELECT 'new', INPUT, METRIC_NAME, EVAL_AGG_SCORE FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
        'GN_DW','SERVING','{agent}','CORTEX AGENT','o216_{k}_v3_{new}')))
    SELECT e.QUESTION_ID, r.METRIC_NAME,
      MAX(IFF(v='old', s, NULL)) o, MAX(IFF(v='new', s, NULL)) n
    FROM r JOIN GN_DW.SERVING.{tbl} e ON e.INPUT_QUERY = r.INPUT
    WHERE r.METRIC_NAME IN ('answer_correctness', 'tool_selection_accuracy')
    GROUP BY 1, 2 ORDER BY 2, 1"""
    c.execute(q)
    rows = c.fetchall()
    for m in ('answer_correctness', 'tool_selection_accuracy'):
        rs = [x for x in rows if x[1] == m]
        ao = sum(x[2] or 0 for x in rs) / max(len(rs), 1)
        an = sum(x[3] or 0 for x in rs) / max(len(rs), 1)
        print(f'{agent} {m}: {old} {ao:.4f} → {new} {an:.4f} (n={len(rs)})')
        for x in rs:
            if x[2] != x[3]:
                print(f'   {x[0]}: {x[2]} → {x[3]}')
