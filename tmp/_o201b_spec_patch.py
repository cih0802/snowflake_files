#!/usr/bin/env python3
# O201-B — Agent 4종 orchestration 식별자 규칙 보강(한글 별칭) · 앵커 1회 치환 · 재읽기 검증
import io, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADD = (' 🔴 [O201-B] 열 별칭(AS 뒤 이름)은 영문·숫자·밑줄만 쓴다(예: AS FORECAST_MONTH) — '
       'AS 예측월 처럼 따옴표 없는 한글 별칭은 syntax error 를 낸다. 한글 명칭은 답변 표 헤더에서만 쓴다.')
T = {
    'AGENT_EXECUTIVE': '따옴표 별칭 안에서만 쓰고 식별자로 쓰지 않는다.',
    'AGENT_MARKETING': '따옴표 별칭 안에서만 쓰고 식별자로 쓰지 않는다.',
    'AGENT_MEMBER': '따옴표 별칭 안에서만 쓰고 식별자로 쓰지 않는다.',
    'AGENT_MSTR': '따옴표 별칭 안에서만 쓴다.',
}
for a, anchor in T.items():
    p = os.path.join(ROOT, 'cortex_project', 'agents', a, 'agent_spec.yaml')
    s = io.open(p, encoding='utf-8').read()
    assert s.count(anchor) == 1 and '[O201-B]' not in s, a
    n = s.replace(anchor, anchor + ADD, 1)
    io.open(p, 'w', encoding='utf-8').write(n)
    back = io.open(p, encoding='utf-8').read()
    assert back == n, a
    print(a, 'OK', len(s), '->', len(back))
