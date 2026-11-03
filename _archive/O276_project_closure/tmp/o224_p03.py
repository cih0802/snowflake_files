# O224 P0-3 — 기준선 문항별 4지표 + 실패 유형 분해(① 도구 선택 ② 도구 실행/SQL ③ 답변 형식·행동)
# 사용: python3 tmp/o224_p03.py <tag>     # run = o224_<agent>_<tag> · 산출 = tmp/o224/p03_<tag>.csv · 요약 stdout
# 판정식(문항 단위 · 점수 0~1): TS<0.5 → ① · (TS≥0.5 & TE<0.5) → ② · (TS≥0.5 & TE≥0.5 & AC<0.7) → ③ · 그 외 → ⭕
#   무도구 정답 문항(정답 도구 0)은 TS/TE 가 「도구를 안 썼는가」를 잰다 ⇒ 같은 식 그대로 적용
# Co-authored with CoCo
import csv, sys, collections
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
tag = sys.argv[1]
AG = {'executive': 'AGENT_EXECUTIVE', 'member': 'AGENT_MEMBER', 'marketing': 'AGENT_MARKETING'}
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
c.execute(f"SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','AGENT_MEMBER','CORTEX AGENT','o224_member_{tag}')) LIMIT 1")
print('COLUMNS', [d[0] for d in c.description])
out, summ = [], collections.Counter()
for k, agent in AG.items():
    c.execute(f"""
    SELECT e.QUESTION_ID, r.METRIC_NAME, AVG(r.EVAL_AGG_SCORE),
           ARRAY_SIZE(ANY_VALUE(e.EXPECTED_OUTPUT:ground_truth_invocations)),
           ANY_VALUE(e.INPUT_QUERY)
    FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','{agent}','CORTEX AGENT','o224_{k}_{tag}')) r
    JOIN GN_DW.SERVING.EVAL_O224_{agent}_V3 e ON e.INPUT_QUERY = r.INPUT
    GROUP BY 1, 2""")
    q = collections.defaultdict(dict)
    meta = {}
    for qid, m, s, ngt, inp in c.fetchall():
        q[qid][m] = s
        meta[qid] = (ngt, inp)
    for qid in sorted(q):
        d = q[qid]
        ac, lc = d.get('answer_correctness'), d.get('logical_consistency')
        ts, te = d.get('tool_selection_accuracy'), d.get('tool_execution_accuracy')
        if None in (ac, ts, te):
            cls = '미채점'
        elif ts < 0.5:
            cls = '① 도구선택'
        elif te < 0.5:
            cls = '② 도구실행'
        elif ac < 0.7:
            cls = '③ 형식·행동'
        else:
            cls = '⭕'
        summ[(agent, cls)] += 1
        out.append([agent, qid, meta[qid][0], ac, lc, ts, te, cls, meta[qid][1]])
    n = len(q)
    avg = lambda m: sum((q[x].get(m) or 0) for x in q) / max(n, 1)
    print(f"{agent} n={n} AC={avg('answer_correctness'):.4f} LC={avg('logical_consistency'):.4f} "
          f"TS={avg('tool_selection_accuracy'):.4f} TE={avg('tool_execution_accuracy'):.4f}")
with open(f'/workspace/tmp/o224/p03_{tag}.csv', 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f)
    w.writerow(['agent', 'qid', 'gt_tools', 'AC', 'LC', 'TS', 'TE', 'class', 'question'])
    w.writerows(out)
for (a, cls), v in sorted(summ.items()):
    print('분해', a, cls, v)
