import io
L = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
t = io.open(L, encoding='utf-8').read()
a = ' · 🟠 잔여 = 80·85 사본 경로(재배치 완료 후)'
b = (' · 🆕 [O275-F·G] 게이트 3종 PASS(rename_stale·live_change·sv_unit) · 80 빌더 MOVE_MAP 변환 계층(내부 옛 이름 유지 · 574=574 · MISSING 0)'
     ' · 85 본문 109건 치환 · 🟢 O275 잔여 0')
assert t.count(a) == 1
t = t.replace(a, b).replace('`-D.md` |', '`-D.md`~`-G.md` |', 1).replace('| 🟡 **`O275`**', '| 🟢 **`O275`**', 1)
io.open(L, 'w', encoding='utf-8').write(t); assert io.open(L, encoding='utf-8').read() == t
print('ok', max(len(x) for x in t.split('\n')))
