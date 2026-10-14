# O224-E — 요건 R 확장: analyst_ml_churn_campaign(SV_ML_CHURN_CAMPAIGN) 를 AGENT_EXECUTIVE · AGENT_MARKETING 에도 배선
# 근거 = 사용자 지시 「EXEC 에도 효용이 있으면 모든 Agent 에 같은 결합 도구」 · MKT V$7 실측 = 같은 질문에 「이어 붙일 수 없다」
#   EXEC = 중단 예측 도구 0 · 캠페인카테고리별 중단 위험 분포는 경영 보고 지표 ⇒ 효용 있음(집계 우선 · 명단은 요청 시)
# 방식 = MEMBER 와 같은 도구 사양(설명 1벌) · 라우팅 1문단을 orchestration 맨 앞 블록 뒤에 삽입 · 편집 외 키 변동 0 · 스냅샷
# 사용: python3 tmp/o224_spec_patch5.py <AGENT_EXECUTIVE|AGENT_MARKETING> [--apply]
# Co-authored with CoCo
import copy, hashlib, io, json, sys
import yaml
sys.path.insert(0, '/workspace/scripts')
import snapshot_util

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
SRC = B % 'AGENT_MEMBER'
NAME = 'analyst_ml_churn_campaign'
ROUTE = (
    '🔴🔴 🆕 [O224-E 중단 예측 × 캠페인 매칭] 「중단 가능성 높은(중단 위험·고위험) 회원 중 ○○캠페인(캠페인카테고리) 후원 회원」·'
    '「캠페인카테고리별 중단 위험 회원수」·「중단 예측과 캠페인 활동회원을 회원번호로 매칭」 질문은 **analyst_ml_churn_campaign 단일 호출**로 답한다 — '
    '두 데이터를 회원번호로 미리 결합해 둔 도구다. 🔴 「두 데이터셋을 결합할 수 없다·이어 붙일 수 없다」고 답하지 않는다. '
    '집계(카테고리별 활동회원수·예측 대상 회원수·고위험 회원수)를 먼저 보이고, 회원번호 명단은 요청할 때 보인다(상위 100명 + 전체 수). '
    '회원 개인 단위 후속 분석(특성·이력)은 회원 분석 Agent 를 안내한다.\n\n'
)


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


a = sys.argv[1]
assert a in ('AGENT_EXECUTIVE', 'AGENT_MARKETING')
src = yaml.safe_load(io.open(SRC, encoding='utf-8').read())
tool = [t for t in src['tools'] if t['tool_spec']['name'] == NAME][0]
res = src['tool_resources'][NAME]
p = B % a
h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
d0 = yaml.safe_load(io.open(p, encoding='utf-8').read())
if NAME in d0['tool_resources']:
    sys.exit(a + ' skip(이미 적용)')
d = copy.deepcopy(d0)
o = d['instructions']['orchestration']
anchor = '(🆕 O224-C).\n\n'
assert o.count(anchor) == 1, (a, 'anchor', o.count(anchor))
d['instructions']['orchestration'] = o.replace(anchor, anchor + ROUTE, 1)
d['tools'].append(copy.deepcopy(tool))
d['tool_resources'][NAME] = copy.deepcopy(res)
x, y = copy.deepcopy(d0), copy.deepcopy(d)
for z in (x, y):
    z['instructions'].pop('orchestration'); z.pop('tools'); z.pop('tool_resources')
assert json.dumps(x, sort_keys=True) == json.dumps(y, sort_keys=True), '편집 외 키 변동'
assert d['tools'][:-1] == d0['tools'], '기존 도구 변동'
names = [t['tool_spec']['name'] for t in d['tools']]
assert set(names) == set(d['tool_resources']) and len(names) == len(set(names)), '도구 집합'
out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
assert yaml.safe_load(out) == d
body = json.dumps(d, ensure_ascii=False, separators=(',', ':'))
assert len(body) <= 100000
print(a, 'tools', len(d0['tools']), '→', len(names), '· orch +', len(ROUTE), '· spec', len(body))
if '--apply' in sys.argv:
    snap, st = snapshot_util.snapshot(p, 'O224E-prepatch', label='O224')
    print('  snapshot', snap, st)
    assert h(p) == h0, a + ' 편집 중 변경됨'
    io.open(p, 'w', encoding='utf-8', newline='').write(out)
    assert yaml.safe_load(io.open(p, encoding='utf-8').read()) == d
    print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
