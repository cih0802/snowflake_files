# O224 P3-C — [O224 도구 호출 전 판정] 예외 문장 확장(EXEC V$5 측정 Q18 회귀 시정)
# 원인 = 「20% 증가를 위해 개선할 요인」을 ① 인과·최적화로 판정해 요인분석 도구를 부르지 않았다(정답 = analyst_ml_feature_importance + 한계 고지)
#   종전 예외 문장은 「머신러닝 시뮬레이터처럼 전용 도구 규칙이 있는 질문」만 예로 들어 요인분석·예측 도구가 빠졌다
# 방식 = o224_spec_patch2 와 같다(정확 문자열 1회 치환 · 편집 외 키 변동 0 · 스냅샷)
# 사용: python3 tmp/o224_spec_patch3.py <AGENT> [--apply]
# Co-authored with CoCo
import copy, hashlib, io, json, sys
import yaml
sys.path.insert(0, '/workspace/scripts')
import snapshot_util

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
OLD = '🔴 지표사전에 산식이 있는 지표(증액율·N개월 유지율 등)와 머신러닝 시뮬레이터처럼 전용 도구 규칙이 있는 질문은 그 규칙을 따른다.'
NEW = ('🔴 **이 판정보다 앞서는 예외** — 질문을 직접 다루는 도구가 있으면 그 도구로 답하고 한계를 밝힌다: '
       '「개선할 요인·영향 요인·무엇이 중요한가」 → 머신러닝 요인분석(상대 중요도 · 인과 아님 고지) · '
       '「예측·전망·가능성 높은 회원」 → 머신러닝 예측 도구 · 「광고비·예산 N% 변동」 → 실시간 시뮬레이터 전용 규칙 · '
       '지표사전에 산식이 있는 지표(증액율·N개월 유지율 등) → 그 산식(🆕 O224-C).')


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


a = sys.argv[1]
p = B % a
h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
d0 = yaml.safe_load(io.open(p, encoding='utf-8').read())
o = d0['instructions']['orchestration']
if 'O224-C' in o:
    sys.exit(a + ' skip(이미 적용)')
assert o.count(OLD) == 1, (a, 'OLD 출현', o.count(OLD))
d = copy.deepcopy(d0)
d['instructions']['orchestration'] = o.replace(OLD, NEW, 1)
x, y = copy.deepcopy(d0), copy.deepcopy(d)
x['instructions'].pop('orchestration'); y['instructions'].pop('orchestration')
assert json.dumps(x, sort_keys=True) == json.dumps(y, sort_keys=True), '편집 외 키 변동'
out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
assert yaml.safe_load(out) == d
print(a, 'orch', len(o), '→', len(d['instructions']['orchestration']), '· tools', len(d['tools']))
if '--apply' in sys.argv:
    snap, st = snapshot_util.snapshot(p, 'O224C-prepatch', label='O224')
    print('  snapshot', snap, st)
    assert h(p) == h0, a + ' 편집 중 변경됨'
    io.open(p, 'w', encoding='utf-8', newline='').write(out)
    assert yaml.safe_load(io.open(p, encoding='utf-8').read()) == d
    print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
