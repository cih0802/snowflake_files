# O241-F/T — VERSION$5 회귀: 스모크 4문항(형식 결함 자동 점검) + native eval(정답지 V5 · tag o241f) · 백그라운드
# 완료 판정 = 상태가 정확히 'COMPLETED'(INVOCATION_COMPLETED 오인 시정) · Co-authored with CoCo
import json, os, re, subprocess, sys, time
B = os.path.dirname(os.path.abspath(__file__)) + '/../../'
sys.path.insert(0, B + 'scripts'); sys.path.insert(0, B + 'tools')
from sfconn import conn
from agent_answer_report import parse
D = B + 'tmp/o241b/eval_s7/'; os.makedirs(D, exist_ok=True)
ST = D + 'state.json'
st = json.load(open(ST)) if os.path.exists(ST) else {}
save = lambda: json.dump(st, open(ST, 'w'), ensure_ascii=False, indent=1)
log = lambda *a: print(time.strftime('%H:%M:%S'), *a, flush=True)
EV = [B + 'tmp/o241b/o224_eval_local.py']
TAG, AGS = 'o241m', 'executive,member,marketing'
cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ETL_WH')

SMOKE = [('S1', 'AGENT_MEMBER', '2026년 9월 선물금참여(원)', ['analyst_relation_activity', 'analyst_service'], ['75,330,000']),
         ('S2', 'AGENT_MARKETING', '2026년 9월 GA 평균세션시간', ['analyst_ga_session'], ['31.8', '90.2']),
         ('S3', 'AGENT_MEMBER', '연도별 결연아동코드 수', ['analyst_ga_child_unpaid'], []),
         ('S4', 'AGENT_MEMBER', '클릭월별 미납서비스 전환율', ['analyst_ga_child_unpaid'], []),
         ('S5', 'AGENT_MEMBER', '2026년 9월 중단 고위험 회원을 연령대별로 보여줘', ['analyst_ml_member_risk'], []),
         ('S6', 'AGENT_MEMBER', '2026년 9월 후원건 이탈 고위험 회원 수를 납입방식별로', ['analyst_ml_sponsor_risk'], [])]


def fmt(ans):
    L = ans.splitlines()
    tbl = [l for l in L if ' | ' in l or l.strip().startswith('|') or re.fullmatch(r'\s*-?[\d.,]+\s*', l)]   # 1열 표 = 숫자만 있는 줄
    sep = lambda l: set(l.replace('|', '').strip()) <= set('-: ')
    hdr = [l for i, l in enumerate(L) if l in tbl and not sep(l) and not re.fullmatch(r'\s*-?[\d.,]+\s*', l) and (i == 0 or L[i - 1] not in tbl)]
    body = '\n'.join(l for l in tbl if l not in hdr)
    nums = re.sub(r'(?<!\d)(19|20)\d{2}(0[1-9]|1[0-2])(\d{2})?(?!\d)', '', body)   # 연월·일자 키 제외
    return {'F1_no_tag': not re.search(r'</?\s*answer\s*>', ans, re.I),
            'F2_comma': not re.search(r'(?<![\d.,])\d{4,}(?![\d.,])', nums),
            'F3_decimal': not re.search(r'\d\.\d{3,}', body),
            'F4_one_summary': ans.count('핵심 요약') <= 1,
            'F5_kor_header': not any(re.search(r'[A-Za-z]{2,}_[A-Za-z_]+', h) for h in hdr)}

if not st.get('smoke'):
    res = []
    for sid, ag, q, wt, wv in SMOKE:
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
                 tools_ok=all(t in p['tools'] for t in wt), vals_ok=all(v in ans for v in wv),
                 ab_both=('A' in ans and 'B' in ans) or '추천안' in ans, provisional='잠정' in ans, no_unanswerable='조회되지 않' not in ans and '미배선' not in ans,
                 no_direct_sql='system_execute_sql' not in p['tools'], **fmt(ans))
        res.append(r); log('SMOKE', json.dumps(r, ensure_ascii=False))
    st['smoke'] = res; save()

log('SMOKE ONLY DONE')
