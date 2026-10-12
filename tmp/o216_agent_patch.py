# O216 — 8차 Agent 스펙 패치(A안 · 6차 롤백 결정 존중 · 도구 집합 무변경)
# 4.2 = MARKETING 무도구 가드레일: 최적 배분·효율 임계점·조합 최적화·증액 시뮬레이션 = 미정의 지표 → 도구 호출 전 확인
# 4.3 = 전 Agent orchestration 에 Analyst 위임 SQL 규칙 요약(정본은 SV AI_SQL_GENERATION · tmp/o216_sv_sqlgen.py)
# 방식 = o213_y4_agent_patch.py 와 같다(safe_load → 편집 → safe_dump width=200 · 왕복 바이트 동일 선검증 · 해시 선확인)
# 사용: python3 tmp/o216_agent_patch.py [--apply]
# Co-authored with CoCo
import hashlib, io, sys, yaml

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
TAG = '🆕 [O216 8차]'
EXPECT = {'AGENT_MEMBER': 22, 'AGENT_EXECUTIVE': 12, 'AGENT_MARKETING': 20}

SQLRULE = (f'\n\n🔴 {TAG} Analyst 위임 SQL 규칙(정본 = 각 SV 의 AI_SQL_GENERATION · O214-A-1 #3). '
           'analyst 도구에 질의를 넘길 때 ① 지표 이름을 컬럼처럼 쓰지 말 것 ② CTE 밖에서 쓰는 차원은 CTE 에서 먼저 선택할 것 '
           '③ 날짜·연도는 그 SV 에 선언된 차원 이름만 쓸 것(CAL_YEAR 같은 물리 컬럼명 추측 금지)을 지킨다. '
           '도구가 invalid identifier 로 실패하면 같은 질의를 그대로 재시도하지 말고 축 이름을 SV 차원 이름으로 바꿔 한 번 다시 묻는다.')

MKT_GUARD = (f'\n\n🔴🔴 {TAG} 무도구 가드레일 — 최적화·시뮬레이션 질문은 「미정의 지표」다. '
             '「다음 달 광고 예산을 어떻게 배분하면 효율이 최대인가」(예산 최적 배분) · 「광고비 효율이 급격히 떨어지는 임계점」(효율 임계점) · '
             '「동일 예산으로 개발 건수가 가장 높은 채널+캠페인 조합」(조합 최적화) · 「광고비를 N% 늘리면 개발건수가 얼마나 늘까」(증액 시뮬레이션·탄력성) 는 '
             '지표사전에 산식이 없고 이를 계산할 모델(탄력성·반응곡선·최적화)도 없다. '
             '⇒ **analyst_ad·analyst_budget 를 먼저 호출하지 않는다.** 먼저 「이 지표는 사전에 정해진 산식이 없습니다 …(O207-C 미정의 지표 문안)… 계산할까요?」라고 묻고, '
             '대안(예: 채널·캠페인별 과거 개발단가·CTR 실적 비교)과 쓸 가정을 1~3줄로 제시한다. 사용자가 계산을 요청한 뒤에만 도구를 호출하고 「Agent 계산값 · 고정값 아님」을 붙인다. '
             '🔴 예산(analyst_budget)과 광고(analyst_ad)를 교차해 배분안을 만들지 않는다(원천이 다르다).')

PATCH = {'AGENT_EXECUTIVE': [SQLRULE], 'AGENT_MEMBER': [SQLRULE], 'AGENT_MARKETING': [MKT_GUARD, SQLRULE]}


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


for a, adds in PATCH.items():
    p = B % a
    h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
    t = io.open(p, encoding='utf-8').read()
    d = yaml.safe_load(t)
    assert yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200) == t, a + ' 왕복 불일치'
    ins = d['instructions']
    if TAG in ins['orchestration']:
        print(a, 'skip(이미 적용)'); continue
    ins['orchestration'] = ins['orchestration'].rstrip('\n') + ''.join(adds) + '\n'
    out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
    d2 = yaml.safe_load(out)
    tools2 = [x['tool_spec']['name'] for x in d2['tools']]
    assert len(tools2) == EXPECT[a] and set(tools2) == set(d2['tool_resources']), a + ' 도구 집합 변동'
    assert d2['instructions']['orchestration'].count(TAG) == len(adds)
    print(f'{a}: tools {len(tools2)} (무변경) · 블록 +{len(adds)} · bytes {len(t.encode())}→{len(out.encode())}')
    if '--apply' in sys.argv:
        assert h(p) == h0, a + ' 편집 중 변경됨'
        io.open(p, 'w', encoding='utf-8', newline='').write(out)
        print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
