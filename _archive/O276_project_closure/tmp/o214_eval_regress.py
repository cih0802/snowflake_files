#!/usr/bin/env python3
"""O214 — eval 퇴행 문항 분해(O211-B VERSION$3 기준선 ↔ O214 VERSION$7) · 과금 없음(관측 이벤트 조회만).
출력 = tmp/o214_eval_regress.tsv (Agent · 문항ID · 지표 · 기준 · 이번 · 기대 도구 · 실제 도구 · 질문)
Co-authored with CoCo
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn  # noqa: E402

AG = {'AGENT_EXECUTIVE': ('o211_executive_v3_ds2', 'o214_executive_v3_ds2', 'EVAL_O211_AGENT_EXECUTIVE_V2'),
      'AGENT_MEMBER': ('o211_member_v3', 'o214_member_v3', 'EVAL_O211_AGENT_MEMBER'),
      'AGENT_MARKETING': ('o211_marketing_v3_ds2', 'o214_marketing_v3_ds2', 'EVAL_O211_AGENT_MARKETING_V2')}
cur = conn().cursor()
out = ['agent\tqid\tmetric\tbase\tnow\texpected\tcalled\tquestion']
for ag, (b, n, ds) in AG.items():
    cur.execute(f"SELECT QUESTION_ID, INPUT_QUERY, EXPECTED_OUTPUT FROM GN_DW.SERVING.{ds}")
    dsq = {r[1].strip(): (r[0], [x['tool_name'] for x in json.loads(r[2]).get('ground_truth_invocations', [])])
           for r in cur.fetchall()}
    cur.execute(f"""SELECT record_attributes FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS('GN_DW','SERVING','{ag}','CORTEX AGENT'))
                    WHERE record_attributes:"snow.ai.observability.run.name"::string IN ('{b}','{n}')""")
    recs, evals = {}, []
    for (ra,) in cur.fetchall():
        a = json.loads(ra)
        st = a.get('ai.observability.span_type')
        run = a.get('snow.ai.observability.run.name')
        if st == 'record_root':
            txt = json.dumps(a, ensure_ascii=False)
            called = sorted(set(re.findall(r'(analyst_[a-z_]+|search_[a-z_]+|sql_exec[a-z_]*)', txt)))
            recs[a['ai.observability.record_id']] = (run, str(a.get('ai.observability.record_root.input', '')).strip(), called)
        elif st == 'eval_root':
            evals.append((run, a.get('ai.observability.eval.target_record_id'), a.get('ai.observability.eval.metric_name'),
                          a.get('ai.observability.eval_root.score')))
    sc = {}
    for run, rid, m, s in evals:
        if rid not in recs:
            continue
        q = recs[rid][1]
        k = (q, m)
        sc.setdefault(k, {})['b' if run == b else 'n'] = (s, recs[rid][2])
    for (q, m), v in sorted(sc.items()):
        if 'b' in v and 'n' in v and v['b'][0] is not None and v['n'][0] is not None and float(v['n'][0]) - float(v['b'][0]) <= -0.3:
            qid, exp = dsq.get(q, ('?', []))
            out.append('\t'.join([ag, qid, m, str(round(float(v['b'][0]), 2)), str(round(float(v['n'][0]), 2)),
                                  ','.join(exp), ','.join(v['n'][1]), q[:90].replace('\t', ' ')]))
io.open('/workspace/tmp/o214_eval_regress.tsv', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(len(out) - 1, 'rows')
