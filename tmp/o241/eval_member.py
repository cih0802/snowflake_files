# O241 — MEMBER eval 채점 완료 대기 후 점수 집계(eval_all.py 의 종료 조건이 INVOCATION_COMPLETED 를 완료로 오인한 보완)
import json, subprocess, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
D = '/workspace/tmp/o241/eval/'
for i in range(45):
    r = subprocess.run(['python3', 'tmp/o224_eval.py', 'status', 'DEFAULT', 'o241', 'member', 'V4'],
                       cwd='/workspace', capture_output=True, text=True)
    print(time.strftime('%H:%M:%S'), r.stdout.strip()[:200], flush=True)
    if "'COMPLETED'" in r.stdout or 'FAILED' in r.stdout:
        break
    time.sleep(120)
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
src = "TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','AGENT_MEMBER','CORTEX AGENT','o224_member_o241'))"
c.execute(f'SELECT METRIC_NAME, AVG(EVAL_AGG_SCORE), COUNT(*), COUNT_IF(EVAL_AGG_SCORE IS NULL) FROM {src} GROUP BY 1')
sc = {x[0]: [round(float(x[1]), 4) if x[1] is not None else None, x[2], x[3]] for x in c.fetchall()}
c.execute(f"""SELECT e.QUESTION_ID, r.EVAL_AGG_SCORE, LEFT(r.INPUT, 80) FROM {src} r
  LEFT JOIN GN_DW.SERVING.EVAL_O224_AGENT_MEMBER_V4 e ON e.INPUT_QUERY = r.INPUT
  WHERE r.METRIC_NAME = 'answer_correctness' AND r.EVAL_AGG_SCORE < 0.67 ORDER BY 1""")
sc['low_ac'] = [list(x) for x in c.fetchall()]
print('SCORE', json.dumps(sc, ensure_ascii=False), flush=True)
st = json.load(open(D + 'state.json'))
st['score']['AGENT_MEMBER'] = sc
json.dump(st, open(D + 'state.json', 'w'), ensure_ascii=False, indent=1)
print('DONE', flush=True)
