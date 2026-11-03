# O206-D — AGENT_MSTR 스펙: 개발(건) 소수 4자리 · 신규기존구분 축 (단일 파일 1회 쓰기 · YAML 검증)
# Co-authored with CoCo
import hashlib, io, sys, yaml
P = 'cortex_project/agents/AGENT_MSTR/agent_spec.yaml'
h = lambda: hashlib.sha256(open(P, 'rb').read()).hexdigest()
assert h() == h()
t = io.open(P, encoding='utf-8').read()
L = t.split('\n')
# 10행: 4자리 표기 규칙 덧붙임
i10 = [i for i, l in enumerate(L) if '소수가 나올 수 있으며 사건 건수가 아니라는 점을 처음 한 번 각주로 밝힌다.' in l]
assert len(i10) == 1
L[i10[0]] = L[i10[0]].replace('각주로 밝힌다.', '각주로 밝힌다. 🆕 [O206-D] 개발(건)은 **소수 4자리**로 표기한다(도구 결과가 이미 4자리로 반올림돼 있다 — 자릿수를 늘리거나 줄이지 않는다).')
# 26·53행: 신규기존구분 축 추가(도구 선택 문장 · 도구 차원 목록)
for key in ('도구 선택: MSTR 정기회원 후원개발 리포트', '      차원: 기준년월·기준일자·개발구분'):
    idx = [i for i, l in enumerate(L) if l.startswith(key) or (key in l and l.lstrip().startswith(key.strip()))]
    assert len(idx) == 1, (key, idx)
    l = L[idx[0]]
    assert '연령대' in l, key
    L[idx[0]] = l.replace('연령대', '연령대·신규기존구분', 1)
new = '\n'.join(L)
# 오케스트레이션: 신규/기존 질문 안내
anchor = '도구 선택: MSTR 정기회원 후원개발 리포트'
j = [i for i, l in enumerate(L) if anchor in l][0]
L[j] = L[j] + ' 🆕 [O206-D] 「신규/기존」 구분 질문은 신규기존구분 차원(MSTR 원천 판정값)으로 답한다 — 가입일이 없다는 이유로 산출 불가라고 답하지 않는다.'
new = '\n'.join(L)
s = yaml.safe_load(new)
assert '신규기존구분' in s['instructions']['orchestration'] and '소수 4자리' in s['instructions']['response']
assert '신규기존구분' in s['tools'][0]['tool_spec']['description']
if '--apply' in sys.argv:
    io.open(P, 'w', encoding='utf-8', newline='').write(new)
    print('WROTE', h()[:12])
else:
    print('DRY OK')
