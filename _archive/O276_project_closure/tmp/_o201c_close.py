import io, re
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
s = io.open(p, encoding='utf-8').read()
old = '| 🟢 소급 12 · 이력 소급 8(`01_세션이력` O201-C 항목) |'
new = ('| 🟢 소급 12 · 이력 소급 8 · 🆕 MSTR 이력 적재 F 3,438,776 · SUM 28,587 · baseline PASS · AGENT_MSTR 일치'
       ' · 비율 5 SV · SV_AD 도달 경고 · 원장 재균형 PASS · 공45~47·54 정의 대기 |')
assert s.count(old) == 1
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)

h = '/workspace/99_NEXT_SESSION_조각/99_NEXT_SESSION-O0201-B.md'
L = io.open(h, encoding='utf-8').read().split('\n')
n = 0
for i, l in enumerate(L):
    m = re.match(r'^\| ([1-9]|10) \| (.+?) \| (.+) \|$', l)
    if not m:
        continue
    k = int(m.group(1))
    tag = '🟢 [O201-C] 종결 — 근거철 §E14·§E15' if k in (1, 2, 3, 4, 5) else '➔ [O201-C] `99_NEXT_SESSION-O0201-C.md` ▣1 로 승계'
    L[i] = '| ~~%d~~ | ~~%s~~ %s | %s |' % (k, m.group(2), tag, m.group(3))
    n += 1
io.open(h, 'w', encoding='utf-8').write('\n'.join(L))
print('index row ok · struck', n)
