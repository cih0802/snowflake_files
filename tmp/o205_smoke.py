#!/usr/bin/env python3
"""O205 AGENT_MEMBER 재질문 스모크 — 회원실 2차 문의 4문항 · 원문 = tmp/o205_smoke/*.json"""
import json, os, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

QS = {
    'Q1': '선넘는좋은일 캠페인을 통해 2026년 1월부터 2026년 9월까지 가입한 회원 중에서 개별화서비스신규(사단)의 선넘는좋은일 즉시 알림톡을 받은 회원과 받지 않은 회원의 온라인 이벤트 및 문화이벤트 참여율 비교해줘',
    'Q2': 'ACPI 행운의 카드 알림톡을 오픈한 후 수신일로부터 5일 이내에 중단한 회원의 가입캠페인, 중단사유, 후원금액, 연령대, 후원사업, 후원기간을 분석하고 분석 내용을 토대로 중단을 방어할 수 있는 전략을 도출해줘',
    'Q3': '알림톡 중 장기회원감사서비스(사단)의 25년 및 26년 수신회원의 후원유지기간 및 이벤트 참여횟수를 분석하고, 각 연도별로 서비스 효과가 가장 높게 나타났던 대상과 가장 낮게 나타났던 대상을 비교해줘. 비교한 내용을 토대로 27년 전략을 도출해줘',
    'Q4': '2026년 1월-9월 캠페인카테고리 구분 기준으로 납입회비금액 확인 및 회비흐름을 분석하고, 2026년 10월-12월의 납입회비를 예측해줘',
}
out = '/workspace/tmp/o205_smoke'
os.makedirs(out, exist_ok=True)
c = conn()
cur = c.cursor()
for k, q in QS.items():
    req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
    try:
        cur.execute('SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ['GN_DW.SERVING.AGENT_MEMBER', req])
        raw = cur.fetchone()[0]
    except Exception as e:
        raw = json.dumps({'error': str(e)})
    open(f'{out}/{k}.json', 'w', encoding='utf-8').write(raw if isinstance(raw, str) else json.dumps(raw))
    d = json.loads(raw) if isinstance(raw, str) else raw
    tools, text = [], []
    for item in d.get('content', []) if isinstance(d, dict) else []:
        if item.get('type') == 'tool_use':
            tools.append(item.get('tool_use', {}).get('name'))
        if item.get('type') == 'text':
            text.append(item.get('text', ''))
    body = ' '.join(text).replace('\n', ' ')
    open(f'{out}/{k}.txt', 'w', encoding='utf-8').write('\n'.join(text))
    print(f'{k} tools={tools} err={d.get("error") if isinstance(d, dict) else None} len={len(body)}')
