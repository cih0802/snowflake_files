import io, re
p = '/workspace/99_NEXT_SESSION_조각/99_NEXT_SESSION-O0201-A.md'
L = io.open(p, encoding='utf-8').read().split('\n')
n = 0
for i, l in enumerate(L):
    m = re.match(r'^\| ([1-9]) \| (.+?) \| (.+) \|$', l)
    if not m:
        continue
    k = int(m.group(1))
    tag = '🟢 [O201-B] 종결 — 근거철 §E10·§E13' if k <= 5 else '➔ [O201-B] `99_NEXT_SESSION-O0201-B.md` ▣1 로 승계'
    L[i] = '| ~~%d~~ | ~~%s~~ %s | %s |' % (k, m.group(2), tag, m.group(3))
    n += 1
io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
print('struck', n)
