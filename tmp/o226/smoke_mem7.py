#!/usr/bin/env python3
"""O226 MEMBER V$7 표적 스모크 — R12·R13(확인 선행 기대) · R14(바로 집계 기대 · 과적용 감시). 원문은 파일로."""
import io, json, os, re, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

OUT = '/workspace/tmp/o226/smoke_mem7'
QS = {
    'R12': '알림톡 중 장기회원감사서비스(사단)의 25년 및 26년 수신회원의 후원유지기간 및 이벤트 참여횟수를 분석하고 각 연도별로 서비스 효과가 가장 높게 나타났던 대상과 가장 낮게 나타났던 대상을 비교해줘. 비교한 내용을 토대로 27년 전략을 도출해줘.',
    'R13': '발송 서비스 기반 유지율 및 증액율 분석',
    'R14': '감액/증액에 따른 콘텐츠 오픈여부 분석',
}
os.makedirs(OUT, exist_ok=True)
cur = conn().cursor()
for tag, q in QS.items():
    req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": q}]}]}, ensure_ascii=False)
    t0 = time.time()
    cur.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)", ('GN_DW.SERVING.AGENT_MEMBER', req))
    raw = cur.fetchall()[0][0]
    io.open(os.path.join(OUT, tag + '.json'), 'w', encoding='utf-8').write(raw)
    d = json.loads(raw)
    tools = [c['tool_use']['name'] for c in d.get('content', []) if 'tool_use' in c]
    text = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
    ask = bool(re.search(r'계산할까요|진행할까요|확인해 주', text))
    print(f'{tag} {time.time()-t0:5.1f}s tools={tools} 확인={ask} | {text[:300]}', flush=True)
