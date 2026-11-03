# O224 P3 — Agent 스펙 패치 생성기(정본 cortex_project/agents/*/agent_spec.yaml)
# ㉠ 3종 공통 = orchestration 맨 앞에 [O224 도구 호출 전 판정] 1문단(산식 없는 지표 · 데이터로 답할 수 없는 질문 → 도구 호출 전에 확인/안내)
#     🔴 범위 = 「산식이 없는 지표(최적화·배분·임계점·효과·조합·대조군)」뿐 — 발행 예측이 없는 「N월 전망」은 기존 결정(O203 T3 · O207-B 추세 참고치)을 따른다
# ㉡ MEMBER = 도구 analyst_ml_churn_campaign(SV_ML_CHURN_CAMPAIGN · 26_) 추가 + [O224 중단 예측 × 캠페인 매칭] 라우팅
#     + 「SV 간 교차계산 금지 · 불가능」 문장 뒤에 사전 결합 도구 안내(문장 자체는 유지 · Analyst 는 SV 1개만 본다는 사실)
# 방식 = YAML 왕복이 바이트 동일하지 않다(O223 수기 편집 형식) ⇒ 의미 동일 검증(편집 키 외 전부 동일) + snapshot_util 스냅샷 후 전체 재작성
# 사용: python3 tmp/o224_spec_patch.py <AGENT> [--apply]
# Co-authored with CoCo
import copy, hashlib, io, json, sys
import yaml
sys.path.insert(0, '/workspace/scripts')
import snapshot_util

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
EXPECT = {'AGENT_MEMBER': 24, 'AGENT_EXECUTIVE': 14, 'AGENT_MARKETING': 25}
TAG = '[O224 도구 호출 전 판정]'
GATE = (
    '🔴🔴 🆕 [O224 도구 호출 전 판정 · 전 Agent 공통 · 최우선] 데이터 도구를 부르기 **전에** 질문이 아래 둘 중 하나인지 먼저 판정한다. '
    '① **사전에 정해진 산식이 없는 지표** — 최적 배분·최적 조합·효율이 급감하는 임계점·N% 늘리면 얼마나 늘까(탄력성)·서비스 효과·대조군 비교·'
    '시나리오(낙관/기본/비관) 같은 **판단·최적화·인과** 질문이면 도구를 호출하지 않고 먼저 「이 지표는 사전에 정해진 산식이 없습니다」라고 밝히고, '
    '쓸 가정(기준 기간·분모·산식)을 1~3줄로 제시한 뒤 계산할지 묻는다. 대안 분석을 길게 덧붙이지 않는다(대안은 한 줄 목록). '
    '사용자가 「계산해 줘」라고 하면 그때 도구를 호출하고 표 위에 가정과 「Agent 계산값 · 고정값 아님」을 적는다. '
    '② **현재 데이터로 답할 수 없는 질문**(방문자 개인 단위 전환 의도·퍼널 단계·신규 사용자 등 원천에 없는 개념)이면 도구를 호출하지 않고 '
    '답할 수 없다고 밝힌 뒤 가능한 대안을 한 줄 목록으로 안내한다 — 대안 조회는 사용자가 고른 뒤에 한다. '
    '🔴 이 판정은 「N월 개발·중단·회비 전망」처럼 **발행된 예측이 없어 추세 참고치로 답하는 질문에는 적용하지 않는다**(그 질문은 아래 기존 규칙대로 추세 참고치로 답한다). '
    '🔴 지표사전에 산식이 있는 지표(증액율·N개월 유지율 등)와 머신러닝 시뮬레이터처럼 전용 도구 규칙이 있는 질문은 그 규칙을 따른다.\n\n'
)
CHURN_TOOL = {
    'tool_spec': {
        'type': 'cortex_analyst_text_to_sql',
        'name': 'analyst_ml_churn_campaign',
        'description': (
            'ML 중단 예측 × 활동 후원 캠페인카테고리 사전 결합(grain=기준월×회원×캠페인카테고리). 원천=GN_DW.ML → SERVING.ML_MEMBER_RISK_V · '
            'SERVING.ML_SPONSOR_RISK_V · CRM(eCRM) → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN → SERVING.ML_CHURN_BY_CMPGN_CTGR_V. '
            '🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계다. '
            '「N월 활동회원 중 중단 가능성 높은 회원 중 ○○캠페인(캠페인카테고리) 후원 회원」의 **회원번호 명단·회원수**를 한 번에 답한다 — '
            '회원 단위 중단 예측(analyst_ml_member_risk)과 캠페인 축을 회원번호로 미리 매칭해 둔 도구다. '
            '활성 지표: 활동회원수·회원 단위 예측 대상 회원수·중단 고위험 회원수·후원건 고위험 회원수·평균 중단확률. '
            '차원: 기준월·회원번호·캠페인카테고리·회원 중단위험 등급·회원 중단 예측 판정·후원건 이탈위험 등급·예측 대상 여부. '
            '🔴 회원 단위 모델은 활동회원 일부만 예측한다 — 명단과 함께 활동회원수·예측 대상 회원수를 분모로 밝힌다. '
            '🔴 회원 단위 등급(기본 「중단 가능성 높은 회원」)과 후원건 단위 등급(「그 캠페인 후원의 이탈 위험」)은 서로 다른 모델이다 — 표 제목에 어느 기준인지 적는다. '
            '🔴 캠페인카테고리 외의 개별 캠페인명·마케팅캠페인 축은 없다.'),
    },
}
CHURN_RES = {'semantic_view': 'GN_DW.SERVING.SV_ML_CHURN_CAMPAIGN',
             'execution_environment': {'type': 'warehouse', 'warehouse': 'GN_DW_ANALYTICS_WH'}}
ROUTE = (
    '🔴🔴 🆕 [O224 중단 예측 × 캠페인 매칭 · 교차 결합 제한 해제] 「중단 가능성 높은(중단 위험·고위험) 회원 중 ○○캠페인(캠페인카테고리)을 후원 중인 회원」·'
    '「중단 예측과 캠페인 활동회원을 회원번호로 매칭」 질문은 **analyst_ml_churn_campaign 단일 호출**로 답한다 — 이 도구는 두 데이터를 회원번호로 미리 결합해 두었다. '
    '🔴 「두 데이터셋을 결합할 수 없다·플랫폼이 차단한다」고 답하지 않는다. 회원번호 명단을 요청하면 명단을 보여 주고(행이 많으면 상위 100명 + 전체 수), '
    '활동회원수·회원 단위 예측 대상 회원수·고위험 회원수를 분모로 함께 밝힌다. '
    '「그 캠페인 후원의 이탈 위험」을 물으면 같은 도구의 후원건 이탈위험 등급을 쓴다. '
    '캠페인카테고리별 위험 분포만 묻는 질문(명단·회원 단위 아님)은 기존대로 analyst_ml_sponsor_risk 를 쓴다.\n\n'
)
CROSS_OLD = '- SV 간 교차계산(cross-fact) 금지.'
CROSS_NEW = ('- SV 간 교차계산(cross-fact) 금지(도구 하나는 SV 하나만 조회한다). '
             '단 중단 예측 × 캠페인카테고리 회원번호 매칭은 사전 결합 도구 analyst_ml_churn_campaign 으로 답한다(🆕 O224).')


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def strip(d, keys):
    x = copy.deepcopy(d)
    for path in keys:
        cur = x
        for k in path[:-1]:
            cur = cur[k]
        cur.pop(path[-1], None)
    return x


a = sys.argv[1]
assert a in EXPECT
p = B % a
h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
t = io.open(p, encoding='utf-8').read()
d0 = yaml.safe_load(t)
assert len(d0['tools']) == EXPECT[a], (a, len(d0['tools']))
d = copy.deepcopy(d0)
o = d['instructions']['orchestration']
if TAG in o:
    sys.exit(a + ' skip(이미 적용)')
log = []
d['instructions']['orchestration'] = GATE + o
log.append('GATE +%d자' % len(GATE))
if a == 'AGENT_MEMBER':
    d['instructions']['orchestration'] = d['instructions']['orchestration'].replace(GATE, GATE + ROUTE, 1)
    log.append('ROUTE +%d자' % len(ROUTE))
    n = 0
    for blk in ('orchestration', 'response', 'system'):
        s = d['instructions'].get(blk, '')
        n += s.count(CROSS_OLD)
        d['instructions'][blk] = s.replace(CROSS_OLD, CROSS_NEW)
    assert n >= 1, ('CROSS_OLD 부재', n)
    log.append('CROSS %d곳' % n)
    d['tools'].append(CHURN_TOOL)
    d['tool_resources']['analyst_ml_churn_campaign'] = CHURN_RES
    log.append('도구 +1')
# 의미 동일 검증: 편집 대상 키를 뺀 나머지가 원본과 같아야 한다
edited = [('instructions', 'orchestration'), ('instructions', 'response'), ('instructions', 'system')]
if a == 'AGENT_MEMBER':
    edited += [('tools',), ('tool_resources',)]
assert json.dumps(strip(d0, edited), sort_keys=True) == json.dumps(strip(d, edited), sort_keys=True), '편집 외 키 변동'
if a == 'AGENT_MEMBER':
    assert d['tools'][:-1] == d0['tools'], '기존 도구 변동'
    assert {k: v for k, v in d['tool_resources'].items() if k != 'analyst_ml_churn_campaign'} == d0['tool_resources']
for blk in ('response', 'system'):
    if a != 'AGENT_MEMBER':
        assert d['instructions'][blk] == d0['instructions'][blk], blk + ' 변동'
assert d['instructions']['orchestration'].endswith(o), 'orchestration 원문 꼬리 변동'
names = [x['tool_spec']['name'] for x in d['tools']]
assert set(names) == set(d['tool_resources']) and len(names) == len(set(names)), '도구 집합 불일치'
out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
assert yaml.safe_load(out) == d, '덤프 왕복 불일치'
body = json.dumps(d, ensure_ascii=False, separators=(',', ':'))
print(a, ' · '.join(log), '· tools', len(d0['tools']), '→', len(names), '· spec', len(body), '자 · orch',
      len(d0['instructions']['orchestration']), '→', len(d['instructions']['orchestration']))
assert len(body) <= 100000, 'spec 100,000 자 초과'
if '--apply' in sys.argv:
    snap, st = snapshot_util.snapshot(p, 'O224-prepatch', label='O224')
    print('  snapshot', snap, st)
    assert h(p) == h0, a + ' 편집 중 변경됨'
    io.open(p, 'w', encoding='utf-8', newline='').write(out)
    assert yaml.safe_load(io.open(p, encoding='utf-8').read()) == d, '쓰기 후 재읽기 불일치'
    print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
