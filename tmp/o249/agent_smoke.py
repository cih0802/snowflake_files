# O249 — ⑤ 재질의 스모크(DATA_AGENT_RUN · 🔴 LLM 호출 과금 · 사용자 승인 2026-10-20)
import io, json, os, sys, time, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts'); sys.path.insert(0, '/workspace/tmp/o245')
from sfconn import conn
from agent_test import texts
OUT = '/workspace/tmp/o249/agent_smoke/'
os.makedirs(OUT, exist_ok=True)
Q = [('M1', 'AGENT_MARKETING', '최근 12개월 개발인입경로별 개발단가를 보여줘'),
     ('M2', 'AGENT_MARKETING', '향후 3개월 신규 개발 건수 예측을 보여줘'),
     ('M3', 'AGENT_MARKETING', '캠페인별 LTV 기대 유지개월을 상한값과 무기한으로 보여줘'),
     ('E1', 'AGENT_MEMBER', '신규 후원 후 12개월 안에 증액한 회원 비율을 사건월별로 보여줘'),
     ('E2', 'AGENT_MEMBER', '최근 발송 제목별 성공 회원수와 실패 회원수 상위 10개를 보여줘')]
CHECK = ['SV_AD_INFLOW_ALLOC', 'FACT_AD_INFLOW_ALLOC', 'ML_DVLP_FORECAST_ALLOC_V', 'FACT_MEMBER_COHORT_SURVIVAL',
         'FACT_MEMBER_EVENT_COHORT', 'FACT_MESSAGE_DISPATCH']
cn = conn(); cur = cn.cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
sel = sys.argv[1:] or [q[0] for q in Q]
for tag, ag, q in Q:
    if tag not in sel:
        continue
    req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    t0 = time.time()
    try:
        cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + ag, req))
        raw = cur.fetchall()[0][0]
    except Exception as e:
        print('=====', tag, 'ERROR', str(e)[:300]); continue
    io.open(OUT + tag + '.txt', 'w', encoding='utf-8').write(str(raw))
    ans, sqls = texts(raw)
    io.open(OUT + tag + '.answer.md', 'w', encoding='utf-8').write(ans)
    print('=====', tag, ag, '%.0fs' % (time.time() - t0), [v for v in CHECK if v in ' '.join(sqls)])
    print(ans[:1200].replace('\n\n', '\n'))
