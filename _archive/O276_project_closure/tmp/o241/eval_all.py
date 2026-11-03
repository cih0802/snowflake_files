# O241 — 스모크 4문항 + native eval(정답지 V4) 3종 · 백그라운드 오케스트레이터
# 사용: python3 tmp/o241/eval_all.py   (로그 = tmp/o241/eval/run.log · 상태 = tmp/o241/eval/state.json)
import json, os, subprocess, sys, time
sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/12_agent개선과제/tools')
from sfconn import conn
from agent_answer_report import parse

D = '/workspace/tmp/o241/eval/'
os.makedirs(D, exist_ok=True)
ST = D + 'state.json'
st = json.load(open(ST)) if os.path.exists(ST) else {}


def save():
    json.dump(st, open(ST, 'w'), ensure_ascii=False, indent=1)


def log(*a):
    print(time.strftime('%H:%M:%S'), *a, flush=True)


def sh(args, out):
    r = subprocess.run(['python3'] + args, cwd='/workspace', capture_output=True, text=True)
    open(D + out, 'w', encoding='utf-8').write(r.stdout + '\n--- stderr ---\n' + r.stderr)
    return r.returncode, r.stdout


cn = conn()
cur = cn.cursor()
cur.execute('USE ROLE GN_DW_ADMIN')
cur.execute('USE WAREHOUSE GN_DW_ETL_WH')

# ① 정답지 데이터셋(V3 → V4) — 계정 이전으로 부재
if not st.get('ds'):
    for g in ('tmp/o224_eval_ds.py', 'tmp/o224_eval_ds_v4.py'):
        rc, out = sh([g, 'apply'], os.path.basename(g) + '.apply.out')
        log('DS', g, 'rc', rc, out.strip().splitlines()[-3:] if out.strip() else '')
        if rc:
            log('🔴 정답지 생성 실패 — 중단'); sys.exit(1)
    st['ds'] = True; save()

# ② 스모크(32 D5) — 기대 = A·B 두 값 + 각 정의 + 「잠정」
SMOKE = [
    ('S1', 'AGENT_MEMBER', '2026년 9월 선물금참여(원)', ['analyst_relation_activity', 'analyst_service'], ['75,330,000']),
    ('S2', 'AGENT_MARKETING', '2026년 9월 GA 평균세션시간', ['analyst_ga_session'], ['31.8', '90.2']),
    ('S3', 'AGENT_MEMBER', '연도별 결연아동코드 수', ['analyst_ga_child_unpaid'], []),
    ('S4', 'AGENT_MEMBER', '클릭월별 미납서비스 전환율', ['analyst_ga_child_unpaid'], []),
]
if not st.get('smoke'):
    res = []
    for sid, ag, q, want_tools, want_vals in SMOKE:
        t0 = time.time()
        req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        try:
            cur.execute('SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + ag, req))
            raw = cur.fetchone()[0]
        except Exception as e:
            raw = json.dumps({'error': str(e)})
        open(D + f'smoke_{sid}.json', 'w', encoding='utf-8').write(raw if isinstance(raw, str) else json.dumps(raw))
        p = parse(raw)
        ans = p['answer'] or ''
        open(D + f'smoke_{sid}.answer.md', 'w', encoding='utf-8').write(ans)
        chk = {
            'tools_ok': all(t in p['tools'] for t in want_tools),
            'vals_ok': all(v in ans for v in want_vals),
            'ab_both': ('A' in ans and 'B' in ans) or ('추천안' in ans),
            'provisional': '잠정' in ans,
        }
        r = dict(id=sid, agent=ag, q=q, sec=round(time.time() - t0, 1), tools=p['tools'], errors=p['errors'], **chk)
        res.append(r); log('SMOKE', json.dumps(r, ensure_ascii=False))
    st['smoke'] = res; save()

# ③ native eval 시작(DEFAULT 버전 = VERSION$4 · 정답지 V4)
TAG = 'o241'
if not st.get('eval_started'):
    rc, out = sh(['tmp/o224_eval.py', 'start', 'DEFAULT', TAG, 'executive,member,marketing', 'V4'], 'eval_start.out')
    log('EVAL START rc', rc, out.strip()[:600])
    if rc or '🔴' in out:
        log('🔴 eval 시작 실패 — 중단'); sys.exit(1)
    st['eval_started'] = True; save()

# ④ 폴링(2분 간격 · 최대 120분)
for i in range(60):
    rc, out = sh(['tmp/o224_eval.py', 'status', 'DEFAULT', TAG, 'executive,member,marketing', 'V4'], 'eval_status.out')
    up = out.upper()
    log('EVAL STATUS', out.strip().replace('\n', ' | ')[:500])
    if up.count('COMPLETED') >= 3 or ('FAILED' in up and 'RUNNING' not in up and 'IN_PROGRESS' not in up):
        break
    time.sleep(120)

# ⑤ 점수(문항 평균 · 4지표)
M = ('answer_correctness', 'logical_consistency', 'tool_selection_accuracy', 'tool_execution_accuracy')
score = {}
for k, ag in (('executive', 'AGENT_EXECUTIVE'), ('member', 'AGENT_MEMBER'), ('marketing', 'AGENT_MARKETING')):
    try:
        cur.execute(f"""SELECT METRIC_NAME, AVG(EVAL_AGG_SCORE), COUNT(*), COUNT_IF(EVAL_AGG_SCORE IS NULL)
            FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','{ag}','CORTEX AGENT','o224_{k}_{TAG}'))
            GROUP BY 1""")
        score[ag] = {r[0]: [round(float(r[1]), 4) if r[1] is not None else None, r[2], r[3]] for r in cur.fetchall()}
        cur.execute(f"""SELECT e.QUESTION_ID, r.METRIC_NAME, r.EVAL_AGG_SCORE, LEFT(r.INPUT, 80)
            FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','{ag}','CORTEX AGENT','o224_{k}_{TAG}')) r
            LEFT JOIN GN_DW.SERVING.EVAL_O224_{ag}_V4 e ON e.INPUT_QUERY = r.INPUT
            WHERE r.METRIC_NAME = 'answer_correctness' AND r.EVAL_AGG_SCORE < 0.67 ORDER BY 1""")
        score[ag]['low_ac'] = [list(x) for x in cur.fetchall()]
    except Exception as e:
        score[ag] = {'error': str(e)[:300]}
    log('SCORE', ag, json.dumps(score[ag], ensure_ascii=False)[:800])
st['score'] = score; save()
log('ALL DONE')
