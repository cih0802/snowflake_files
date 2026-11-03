# O216-C — 9차 Agent 스펙 패치(도구 집합 무변경 · O216-B 분석 처방)
# ㉠ 전 Agent = MSTR 우선 라우팅 정정 — O207 교차 규칙의 「MSTR 에 없는 축」 목록이 O212 이후 SV 와 어긋남
#    (캠페인카테고리·UTM·마케팅채널·마케팅캠페인·후원구분은 SV_MSTR_SPNSR_DVLP 에 실재 · 2026-10-12 DESCRIBE 실측)
# ㉡ 전 Agent = 같은 도구 반복 호출 억제(MEMBER 도구선택 감점 주원인 · O216-B-2)
# ㉢ EXEC = 회비 예측·시뮬레이션은 계산 제안 없이 회원 분석 어시스턴트 안내만(Q03~Q06 · O216-B-1 ㉠)
# 방식 = o216_agent_patch.py 와 같다(왕복 바이트 동일 선검증 · 해시 선확인 · 도구 집합 assert)
# 사용: python3 tmp/o216c_agent_patch.py [--apply]
# Co-authored with CoCo
import hashlib, io, sys, yaml

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
TAG = '🆕 [O216-C 9차]'
EXPECT = {'AGENT_MEMBER': 22, 'AGENT_EXECUTIVE': 12, 'AGENT_MARKETING': 20}

MSTR = (f'\n\n🔴🔴 {TAG} MSTR 우선 라우팅(O207 교차 규칙의 「MSTR 에 없는 축」 목록을 이 문단이 대체한다). '
        '개발 실적(개발(건)·개발(명)·후원금액)·개발 목표·달성률·연도말 개발 추세 질문은 축이 아래 중 하나이면 **analyst_mstr_spnsr_dvlp 를 먼저 쓴다**: '
        '부서(구분_팀·본부/지부·팀/지부·부서)·법인·캠페인·상위캠페인·캠페인카테고리(주요캠페인)·캠페인유형(국내/해외)·캠페인유형2(사업/사례)·브랜드·공통브랜드·'
        '개발인입경로·마케팅캠페인·마케팅 UTM·마케팅채널·후원구분(정기/일시)·홍보방법·후원사업·후원사업2·후원약칭·신규기존·개발구분·후원기간대·후원금액대·결제수단·'
        '회원구분·시도·성별·연령대·중단/감액 사유·직전캠페인. '
        '기존 GN_DW 도구로 답하는 경우는 셋뿐이다 — ① MSTR 에 없는 영역(회비·납입·발송·행사·코호트·유지율·GA·광고비·예산·ML 예측·피처 중요도) '
        '② 개발 × ① 영역 교차 ③ MSTR 적재 기간(2024-01~) 밖의 기간. '
        '🔴 MSTR 개발(건) = 후원금액 ÷ 10,000 이다(사건 수가 아니다) — 사용자가 「몇 건이 발생했나」처럼 사건 수를 명시하면 GN_DW 도구로 답하고 기준 차이를 1줄 밝힌다. '
        '🔴🔴 MSTR 기준과 GN_DW 기준 수치를 한 표에서 합산·차감·비율 계산하지 않는다 — 함께 필요하면 표를 나누고 각 표 제목에 기준을 단다.')

REPEAT = (f'\n\n🔴 {TAG} 도구 호출 절약 — 같은 도구는 한 질문에 **1회**를 원칙으로 한다. '
          '여러 축·기간·지표가 필요하면 한 번의 질의에 모아 넘긴다(예: 「월별 × 개발구분별 개발(건)과 개발(명)」을 한 질의로). '
          '같은 도구를 다시 부르는 경우는 ㉠ 직전 호출이 오류였을 때 축 이름을 고쳐 1회 ㉡ 그 도구 안에서 서로 조인되지 않는 표가 따로 필요할 때'
          '(analyst_mstr_spnsr_dvlp 의 실적 md · 목표 gl · 연도말 추세 ye · 후원사업 추세 yb) 뿐이다. '
          '결과를 검산하려고 같은 질의를 다시 보내지 않는다.')

FEE = (f'\n\n🔴🔴 {TAG} 회비 예측·회비 시뮬레이션·회비 분해 질문(연간·연도말·추경·시나리오·캠페인카테고리별 회비 예측 포함)은 이 Agent 의 도구 범위 밖이다. '
       '**계산을 제안하지 않는다** — 「가정으로 계산해 드릴까요」 같은 선택지·산식 예시·가정 목록을 내지 않고, '
       '「회비 예측은 회원 분석 어시스턴트에서 조회 가능합니다」라고 안내한 뒤 사전에 정해진 산식이 없는 지표임을 1줄 밝힌다. '
       '이 규칙이 [O207-C 미정의 지표] 의 「가정 제시 후 계산할지 묻기」보다 우선한다(회비 영역 한정).')

PATCH = {'AGENT_EXECUTIVE': [MSTR, REPEAT, FEE], 'AGENT_MEMBER': [MSTR, REPEAT], 'AGENT_MARKETING': [MSTR, REPEAT]}


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
    assert 'analyst_mstr_spnsr_dvlp' in tools2, a + ' MSTR 도구 부재'
    assert d2['instructions']['orchestration'].count(TAG) == len(adds)
    print(f'{a}: tools {len(tools2)} (무변경) · 블록 +{len(adds)} · bytes {len(t.encode())}→{len(out.encode())}')
    if '--apply' in sys.argv:
        assert h(p) == h0, a + ' 편집 중 변경됨'
        io.open(p, 'w', encoding='utf-8', newline='').write(out)
        print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
