# O242 — VERSION$7 회귀: S4 스모크 1문항(O242 VQR 한글 별칭 확인) + native eval(정답지 V6 · tag o241s) · 백그라운드
# 원형 = tmp/o241b/eval_m.py(판정 함수 fmt 동일) · Co-authored with CoCo
import json, os, re, subprocess, sys, time
B = os.path.dirname(os.path.abspath(__file__)) + '/../../'
sys.path.insert(0, B + 'scripts'); sys.path.insert(0, B + '12_agent개선과제/tools')
from sfconn import conn
from agent_answer_report import parse
D = B + 'tmp/o242/eval_s/'; os.makedirs(D, exist_ok=True)
ST = D + 'state.json'
st = json.load(open(ST)) if os.path.exists(ST) else {}
save = lambda: json.dump(st, open(ST, 'w'), ensure_ascii=False, indent=1)
log = lambda *a: print(time.strftime('%H:%M:%S'), *a, flush=True)
EV = [B + 'tmp/o241b/o224_eval_local.py']
TAG, AGS, DSV = 'o241s', 'executive,member,marketing', 'V6'
cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ETL_WH')

SMOKE = [('S4', 'AGENT_MEMBER', '클릭월별 미납서비스 전환율', ['13.64', '33.10'])]


def fmt(ans):
    L = ans.splitlines()
    tbl = [l for l in L if ' | ' in l or l.strip().startswith('|') or re.fullmatch(r'\s*-?[\d.,]+\s*', l)]
    sep = lambda l: set(l.replace('|', '').strip()) <= set('-: ')
    hdr = [l for i, l in enumerate(L) if l in tbl and not sep(l) and not re.fullmatch(r'\s*-?[\d.,]+\s*', l) and (i == 0 or L[i - 1] not in tbl)]
    body = '\n'.join(l for l in tbl if l not in hdr)
    nums = re.sub(r'(?<!\d)(19|20)\d{2}(0[1-9]|1[0-2])(\d{2})?(?!\d)', '', body)
    return {'F1_no_tag': not re.search(r'</?\s*answer\s*>', ans, re.I),
            'F2_comma': not re.search(r'(?<![\d.,])\d{4,}(?![\d.,])', nums),
            'F3_decimal': not re.search(r'\d\.\d{3,}', body),
            'F4_one_summary': ans.count('핵심 요약') <= 1,
            'F5_kor_header': not any(re.search(r'[A-Za-z]{2,}_[A-Za-z_]+', h) for h in hdr)}

if not st.get('smoke'):
    res = []
    for sid, ag, q, wv in SMOKE:
        t0 = time.time()
        req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        try:
            cur.execute('SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + ag, req)); raw = cur.fetchone()[0]
        except Exception as e:
            raw = json.dumps({'error': str(e)})
        open(D + f'smoke_{sid}.json', 'w', encoding='utf-8').write(raw if isinstance(raw, str) else json.dumps(raw))
        p = parse(raw); ans = p['answer'] or ''
        open(D + f'smoke_{sid}.answer.md', 'w', encoding='utf-8').write(ans)
        r = dict(id=sid, agent=ag, q=q, sec=round(time.time() - t0, 1), tools=p['tools'], errors=p['errors'],
                 vqr_used='"verified_query_used": true' in (raw if isinstance(raw, str) else json.dumps(raw)),
                 kor_cols='미납서비스 전환율(추천안A)(%)' in (raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False)),
                 vals_ok=all(v in ans for v in wv), **fmt(ans))
        res.append(r); log('SMOKE', json.dumps(r, ensure_ascii=False))
    st['smoke'] = res; save()

if not st.get('eval_started'):
    r = subprocess.run(['python3'] + EV + ['start', 'DEFAULT', TAG, AGS, DSV], capture_output=True, text=True)
    log('EVAL START', r.returncode, r.stdout.strip()[:600])
    if r.returncode or '🔴' in r.stdout:
        log('🔴 eval 시작 실패'); sys.exit(1)
    st['eval_started'] = True; save()

for i in range(75):
    r = subprocess.run(['python3'] + EV + ['status', 'DEFAULT', TAG, AGS, DSV], capture_output=True, text=True)
    out = r.stdout; log('STATUS', out.strip().replace('\n', ' | ')[:500])
    done = len(re.findall(r"'COMPLETED'", out)); fail = out.upper().count('FAILED')
    if done + fail >= 3:
        break
    time.sleep(120)

score = {}
for k in ('executive', 'member', 'marketing'):
    ag = 'AGENT_' + k.upper()
    src = f"TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','{ag}','CORTEX AGENT','o224_{k}_{TAG}'))"
    try:
        cur.execute(f'SELECT METRIC_NAME, AVG(EVAL_AGG_SCORE), COUNT(*), COUNT_IF(EVAL_AGG_SCORE IS NULL) FROM {src} GROUP BY 1')
        score[ag] = {x[0]: [round(float(x[1]), 4) if x[1] is not None else None, x[2], x[3]] for x in cur.fetchall()}
        cur.execute(f"""SELECT e.QUESTION_ID, r.METRIC_NAME, r.EVAL_AGG_SCORE FROM {src} r
            LEFT JOIN GN_DW.SERVING.EVAL_O224_{ag}_{DSV} e ON e.INPUT_QUERY = r.INPUT ORDER BY 1, 2""")
        score[ag]['per_q'] = [list(x) for x in cur.fetchall()]
    except Exception as e:
        score[ag] = {'error': str(e)[:300]}
    log('SCORE', ag, json.dumps({m: v for m, v in score[ag].items() if m != 'per_q'}, ensure_ascii=False))
st['score'] = score; save()
log('ALL DONE')
