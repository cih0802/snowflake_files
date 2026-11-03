# O246 — Agent 스모크(B = O246-B 3문항)(DATA_AGENT_RUN · 🔴 LLM 호출 과금)
import io, json, sys, time
sys.path.insert(0, '/workspace/scripts'); sys.path.insert(0, '/workspace/tmp/o245')
from sfconn import conn
from agent_test import texts
Q0 = [('F1', '최신 기준월 기준 향후 12개월 회비 예측을 후원사업별 상위 5개로 보여줘'),
     ('R1', 'ML 회원 중단 예측 최신 기준월 고위험 회원을 후원금액대별로 나눠 회원수를 보여줘')]
Q = [('B1', 'AGENT_MEMBER', '최신 기준월 중단 고위험 회원을 마케팅캠페인명별 상위 5개로 보고 기대 중단 회원수와 회비 위험액도 알려줘'),
     ('B2', 'AGENT_EXECUTIVE', '향후 12개월 개발 예측을 후원사업별로 보여줘'),
     ('B3', 'AGENT_MARKETING', '중단 예측 고위험 회원을 UTM별로 나눠줘')]
cn = conn(); cur = cn.cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
for tag, ag, q in Q:
    req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    t0 = time.time(); cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + ag, req))
    raw = cur.fetchall()[0][0]; io.open('/workspace/tmp/o246/agent_test/%s.txt' % tag, 'w', encoding='utf-8').write(str(raw))
    ans, sqls = texts(raw)
    print('=====', tag, '%.0fs' % (time.time() - t0), [v for v in ['ML_MEMBER_PRED_BRIDGE_V','ML_DVLP_FORECAST_ALLOC_V'] if v in ' '.join(sqls)], '\n', ans[-1600:])
