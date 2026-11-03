# O213-Y4 — 7차 신규 도구·축 NL 라우팅 스모크(10문항 · 기대 도구 + 기대 수치 일부 포함 여부)
import json, os, re, sys, concurrent.futures as cf
import snowflake.connector
Q = [
 ('AGENT_MARKETING', '2026년 9월 구글 검색 클릭수와 노출수, 클릭률을 알려줘', 'analyst_search_console', ['3,633', '3633']),
 ('AGENT_MARKETING', '2026년 9월 성별 홈페이지 세션수를 보여줘', 'analyst_ga_demographic', ['326,502', '326502']),
 ('AGENT_MARKETING', '2026년 매체별 광고비 상위 5개를 보여줘', 'analyst_ad', []),
 ('AGENT_MARKETING', '부서별 지출결의 금액 상위 5개 부서는? 2026년', 'analyst_expense_resolution', []),
 ('AGENT_EXECUTIVE', '2026년 부서별 지출결의 금액 상위 10개 부서는?', 'analyst_expense_resolution', []),
 ('AGENT_EXECUTIVE', '2026년 8월 회비 청구구분별 청구 건수와 청구액을 보여줘', 'analyst_payment_billing_status', ['922,963', '922963']),
 ('AGENT_EXECUTIVE', '예산 장별 2026년 편성액을 보여줘', 'analyst_budget', []),
 ('AGENT_MEMBER', '2026년 8월 회비 청구구분별 청구 건수와 청구액을 보여줘', 'analyst_payment_billing_status', ['922,963', '922963']),
 ('AGENT_MEMBER', '결연 중단 사유별 서신·선물금 활동 건수를 보여줘', 'analyst_relation_activity', []),
 ('AGENT_MEMBER', '결연구분별 2025년 신규 개발 건수는?', None, []),
]


def run(q):
    a, text, exp, nums = q
    tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
    c = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                    authenticator='oauth', token=tok, role='GN_DW_ANALYST', warehouse='GN_DW_ANALYTICS_WH')
    req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": text}]}]}, ensure_ascii=False)
    try:
        cu = c.cursor(); cu.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)", (f'GN_DW.SERVING.{a}', req))
        r = cu.fetchone()[0]
    except Exception as e:
        return a, text, exp, 'ERR', str(e)[:150], []
    tools = sorted(set(re.findall(r'"name"\s*:\s*"(analyst_[a-z_]+)"', r)))
    err = 'error' in r.lower() and '"status":"error"' in r.replace(' ', '')
    num = (not nums) or any(n in r for n in nums)
    ok = ((exp is None) or (exp in tools)) and num and not err
    open(f'/workspace/tmp/nlsmoke/o213_{a}_{abs(hash(text))%10**6}.json', 'w').write(r)
    return a, text, exp, 'OK' if ok else 'CHECK', f'num={num} err={err}', tools


os.makedirs('/workspace/tmp/nlsmoke', exist_ok=True)
with cf.ThreadPoolExecutor(4) as ex:
    res = list(ex.map(run, Q))
n = 0
for a, text, exp, st, info, tools in res:
    n += st == 'OK'
    print(st, a, '|', text, '| 기대', exp, '| 호출', tools, '|', info)
print(f'PASS {n}/{len(Q)}')
