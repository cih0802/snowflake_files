# O224 P3-B — [O224 도구 호출 전 판정] ② 범위 축소(MKT V$6 측정 Q33 회귀 시정)
# 원인 = ② 예시 「신규 사용자」 때문에 집계 대리 지표(채널별 세션 분포)로 답할 질문까지 거절했다(T9 기대 = 대리 지표 + 한계 고지)
# 방식 = 정본 dict 에서 정확 문자열 1회 치환 · 편집 외 키 변동 0 단정 · snapshot_util 스냅샷 후 쓰기
# 사용: python3 tmp/o224_spec_patch2.py <AGENT> [--apply]
# Co-authored with CoCo
import copy, hashlib, io, json, sys
import yaml
sys.path.insert(0, '/workspace/scripts')
import snapshot_util

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
OLD = ('② **현재 데이터로 답할 수 없는 질문**(방문자 개인 단위 전환 의도·퍼널 단계·신규 사용자 등 원천에 없는 개념)이면 도구를 호출하지 않고 '
       '답할 수 없다고 밝힌 뒤 가능한 대안을 한 줄 목록으로 안내한다 — 대안 조회는 사용자가 고른 뒤에 한다. ')
NEW = ('② **질문의 대상 자체가 원천에 없는 질문**(방문자 개인 단위 전환 의도·재방문 예측·퍼널 단계 라벨처럼 **개인 단위 판정**을 요구)이면 도구를 호출하지 않고 '
       '답할 수 없다고 밝힌 뒤 가능한 대안을 한 줄 목록으로 안내한다 — 대안 조회는 사용자가 고른 뒤에 한다. '
       '🔴 단 질문이 **채널·매체·카테고리별 분포·순위**를 묻고 그 지표만 원천에 없을 때(예: 「신규 사용자 확보 상위 채널」)는 거절하지 않고 '
       '가장 가까운 집계 대리 지표(채널별 세션·식별 방문자 분포 등)로 답하면서 「요청 지표는 원천에 없어 대리 지표로 답한다」는 한계를 첫 줄에 밝힌다(🆕 O224-B). ')


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


a = sys.argv[1]
p = B % a
h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
d0 = yaml.safe_load(io.open(p, encoding='utf-8').read())
o = d0['instructions']['orchestration']
if 'O224-B' in o:
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
    snap, st = snapshot_util.snapshot(p, 'O224B-prepatch', label='O224')
    print('  snapshot', snap, st)
    assert h(p) == h0, a + ' 편집 중 변경됨'
    io.open(p, 'w', encoding='utf-8', newline='').write(out)
    assert yaml.safe_load(io.open(p, encoding='utf-8').read()) == d
    print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
