import io, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot
L = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
print(snapshot(L, 'pre-rebuildtag', label='O275-F')[1])
t = io.open(L, encoding='utf-8').read()
a = '| 🟡 1~59 구축 · A·B·C·E·F 운영계 일치'
b = '| 🟡 1~59 구축 · 🆕 [O275-F] REBUILD:ALL 2026-10-30(TQ68205 개발계 신규 구축 1~59 · SV 전건·Agent 3 · live_change_gate 무기록 48 해소) · A·B·C·E·F 운영계 일치'
assert t.count(a) == 1
t = t.replace(a, b)
io.open(L, 'w', encoding='utf-8').write(t)
assert io.open(L, encoding='utf-8').read() == t
print('ok', max(len(x) for x in t.split('\n')))
