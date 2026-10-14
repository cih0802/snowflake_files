# O224 P3-D — AGENT_MEMBER 에서만 [O224 도구 호출 전 판정] 블록 제거(요건 R 도구·라우팅은 유지)
# 근거 = MEMBER V$5 native eval(V3) AC 0.8715 → 0.8200(−0.05 · 잡음 폭 ±0.024 초과)
#   ㉠ 과적용 R14(정의·도구가 있는 분석을 「산식 없음」으로 확인부터 물음 · 1.0 → 0.33)
#   ㉡ 미적용 R12·R13(MEMBER 는 [O217 정의 조회] 가 search_biz_definition 을 먼저 불러 「산식 있음」으로 판단 → 계산 · 변화 없음)
#   ⇒ 같은 규칙이 양방향으로 어긋났다 · 덧붙이기(K6 재발) 대신 MEMBER 에서는 이 블록만 되돌린다 · MKT·EXEC 는 측정상 유지
# 방식 = 블록(첫 줄 「🔴🔴 🆕 [O224 도구 호출 전 판정」 ~ 「(🆕 O224-C).\n\n」)을 정확히 1회 제거 · 편집 외 키 변동 0 · 스냅샷
# 사용: python3 tmp/o224_spec_patch4.py [--apply]
# Co-authored with CoCo
import copy, hashlib, io, json, sys
import yaml
sys.path.insert(0, '/workspace/scripts')
import snapshot_util

p = '/workspace/cortex_project/agents/AGENT_MEMBER/agent_spec.yaml'
HEAD = '🔴🔴 🆕 [O224 도구 호출 전 판정'
TAIL = '(🆕 O224-C).\n\n'


def h(x):
    return hashlib.sha256(open(x, 'rb').read()).hexdigest()


h0 = h(p); assert h0 == h(p), '해시 불안정'
d0 = yaml.safe_load(io.open(p, encoding='utf-8').read())
o = d0['instructions']['orchestration']
assert o.count(HEAD) == 1 and o.startswith(HEAD), 'HEAD 위치'
k = o.find(TAIL); assert k > 0 and o.count(TAIL) == 1, 'TAIL'
block = o[:k + len(TAIL)]
rest = o[k + len(TAIL):]
assert rest.startswith('🔴🔴 🆕 [O224 중단 예측 × 캠페인 매칭'), '요건 라우팅이 바로 뒤에 있어야 한다'
d = copy.deepcopy(d0)
d['instructions']['orchestration'] = rest
x, y = copy.deepcopy(d0), copy.deepcopy(d)
x['instructions'].pop('orchestration'); y['instructions'].pop('orchestration')
assert json.dumps(x, sort_keys=True) == json.dumps(y, sort_keys=True), '편집 외 키 변동'
assert '[O224 도구 호출 전 판정' not in json.dumps(d, ensure_ascii=False), '잔존'
assert 'analyst_ml_churn_campaign' in d['tool_resources'], '요건 도구 유실'
out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
assert yaml.safe_load(out) == d
print('MEMBER orch', len(o), '→', len(rest), '· 제거', len(block), '자 · tools', len(d['tools']))
if '--apply' in sys.argv:
    snap, st = snapshot_util.snapshot(p, 'O224D-prepatch', label='O224')
    print('  snapshot', snap, st)
    assert h(p) == h0, '편집 중 변경됨'
    io.open(p, 'w', encoding='utf-8', newline='').write(out)
    assert yaml.safe_load(io.open(p, encoding='utf-8').read()) == d
    print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
