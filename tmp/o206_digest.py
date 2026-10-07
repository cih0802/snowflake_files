# O206 — 3차 측정 요지 추출: 문항별 도구 · 표 수 · 답변 첫 400자 · 불가/대안 키워드
# Co-authored with CoCo
import glob, json, os, re, sys
D = sys.argv[1]
KW = ['산출할 수 없', '답변할 수 없', '불가', '없습니다', '추세 참고치', '모델이', '예측', '대조군', '매핑', '오픈']
for p in sorted(glob.glob(f'{D}/*.json')):
    d = json.load(open(p, encoding='utf-8'))
    if 'content' not in d:
        print(os.path.basename(p), 'ERROR', str(d)[:200]); continue
    tools = [c['tool_use']['name'] for c in d['content'] if c.get('type') == 'tool_use']
    tools = [t for t in tools if not t.startswith('system')] or tools
    tables = sum(1 for c in d['content'] if c.get('type') == 'table')
    txt = ' '.join(c['text'] for c in d['content'] if c.get('type') == 'text').replace('\n', ' ')
    print('==', os.path.basename(p)[:-5], 'tools=', sorted(set(tools)), 'tables=', tables)
    print('   ', txt[:420])
    print('   kw:', {k: txt.count(k) for k in KW if k in txt})
