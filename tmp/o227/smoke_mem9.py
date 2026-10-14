#!/usr/bin/env python3
"""O227 MEMBER V$9 표적 스모크 — D3(eval 회귀 감시 · 바로 집계 기대) · R14(바로 집계 기대) · R13(확인 선행 기대). 원문은 파일로.
원본 = tmp/o226/smoke_mem7.py. Co-authored with CoCo"""
import io, json, os, re, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

OUT = '/workspace/tmp/o227/smoke_mem9'
QS = {
    'D3': '2026년 9월 후원중단 사유별 중단 건수와 회원수',
    'R14': '감액/증액에 따른 콘텐츠 오픈여부 분석',
    'R13': '발송 서비스 기반 유지율 및 증액율 분석',
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
