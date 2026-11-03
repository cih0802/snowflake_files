# O216-D — 9차 정정: O216-C 의 「사건 수 명시 시 GN_DW」 예외 삭제(O202 사용자 결정 「개발(건) 단위 = MSTR 정의」 위반)
# 근거 = 99_NEXT_SESSION-O0201-D.md:31 · 12_agent개선과제/00_작업계획.md:279(C안 · MSTR = 개발 지표 정본)
# 방식 = o216c 와 같다(왕복 바이트 동일 선검증 · 해시 선확인 · 도구 집합 assert)
# 사용: python3 tmp/o216d_agent_fix.py [--apply]
# Co-authored with CoCo
import hashlib, io, sys, yaml

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
EXPECT = {'AGENT_MEMBER': 22, 'AGENT_EXECUTIVE': 12, 'AGENT_MARKETING': 20}
OLD = ('🔴 MSTR 개발(건) = 후원금액 ÷ 10,000 이다(사건 수가 아니다) — 사용자가 「몇 건이 발생했나」처럼 사건 수를 명시하면 '
       'GN_DW 도구로 답하고 기준 차이를 1줄 밝힌다. ')
NEW = ('🔴🔴 🆕 [O216-D] 개발(건)·개발건수·개발 몇 건 질문은 **표현과 무관하게 MSTR 정의(후원금액 ÷ 10,000)로 답한다**'
       '(O202 사용자 결정 · 개발 지표 정본 = MSTR) — GN_DW 사건 수로 바꿔 답하지 않는다. 처음 한 번 「MSTR 개발(건) = 후원금액 ÷ 10,000」 각주를 단다. ')


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


for a in EXPECT:
    p = B % a
    h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
    t = io.open(p, encoding='utf-8').read()
    d = yaml.safe_load(t)
    assert yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200) == t, a + ' 왕복 불일치'
    o = d['instructions']['orchestration']
    if '[O216-D]' in o:
        print(a, 'skip(이미 적용)'); continue
    assert o.count(OLD) == 1, a + ' 대상 문장 수 ≠ 1'
    d['instructions']['orchestration'] = o.replace(OLD, NEW)
    out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
    d2 = yaml.safe_load(out)
    tools2 = [x['tool_spec']['name'] for x in d2['tools']]
    assert len(tools2) == EXPECT[a] and set(tools2) == set(d2['tool_resources']), a + ' 도구 집합 변동'
    assert OLD not in d2['instructions']['orchestration'] and d2['instructions']['orchestration'].count('[O216-D]') == 1
    print(f'{a}: tools {len(tools2)} (무변경) · 예외 문장 교체 1 · bytes {len(t.encode())}→{len(out.encode())}')
    if '--apply' in sys.argv:
        assert h(p) == h0, a + ' 편집 중 변경됨'
        io.open(p, 'w', encoding='utf-8', newline='').write(out)
        print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
