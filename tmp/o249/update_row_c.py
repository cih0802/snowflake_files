import io
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
L = io.open(p, encoding='utf-8').readlines()
assert L == io.open(p, encoding='utf-8').readlines()
i = next(k for k, l in enumerate(L) if '**`O249`**' in l)
old = L[i]
new = old.replace('| 🟢 **`O249`**', '| 🟡 **`O249`**', 1).replace('단위 O249-A · O249-B)', '단위 O249-A · O249-B · O249-C)', 1)
new = new.replace('| 🟢 스모크 5/5', '| 🟡 스모크 5/5', 1).replace('👤 잔여 = dim 3 build · 현업 회신 ', '🆕 C = 템플릿 dim 고아 0 · 👤 잔여 = DIM_SEND_REQUEST 재 build(센티넬 키 0 시정) · 현업 회신 ', 1)
new = new.replace('99_NEXT_SESSION-O0249-B.md` |', '99_NEXT_SESSION-O0249-C.md` |', 1)
assert new != old and new.count('O0249-C') == 1
L[i] = new
io.open(p, 'w', encoding='utf-8').write(''.join(L))
print('row len', len(new))
