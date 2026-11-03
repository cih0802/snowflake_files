# O207 W5 — 라우팅 판정: 개발 문항이 기대 도구(MSTR / GN_DW)로 갔는가 + 「추세 참고치」·「MSTR 기준」 고지 여부
# 사용: python3 tmp/o207_w5_route.py
# Co-authored with CoCo
import json, os, sys
sys.path.insert(0, '/workspace/tmp')
from o207_w5 import CASES, OUT

MSTR = 'analyst_mstr_spnsr_dvlp'


def tools_used(d):
    names = []

    def walk(x):
        if isinstance(x, dict):
            for k in ('name', 'tool_name'):
                v = x.get(k)
                if isinstance(v, str) and v.startswith('analyst_'):
                    names.append(v)
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)
    walk(d.get('content', []))
    return sorted(set(names))


tot = {'PASS': 0, 'FAIL': 0}
for k, agent, exp, q in CASES:
    p = f'{OUT}/{k}.json'
    if not os.path.exists(p):
        print(k, 'MISSING'); tot['FAIL'] += 1; continue
    d = json.load(open(p, encoding='utf-8'))
    used = tools_used(d)
    txt = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
    if exp == 'MSTR':
        ok = MSTR in used
        note = ('MSTR기준표기=%s' % ('MSTR' in txt))
        if '예측' in q or '전망' in q:
            note += ' 추세참고치표기=%s' % ('추세 참고치' in txt or '추세참고치' in txt)
    else:
        ok = bool(used) and any(u != MSTR for u in used)
        note = 'GN_DW기준표기=%s' % ('GN_DW' in txt)
    v = 'PASS' if ok else 'FAIL'
    tot[v] += 1
    print(f'{k:4} {agent:16} 기대={exp:4} {v} 도구={used} {note}')
print(tot)
