import io
p = '/workspace/scripts/build_wide_doc.py'
L = io.open(p, encoding='utf-8').read().split('\n')
n = 0
for i in range(449, 495):
    s = L[i]
    if '14종' in s or '575컬럼' in s:
        assert s.lstrip().startswith("a('") and '{' not in s, (i, s)
        s = s.replace("a('", "a(f'", 1).replace('14종', '{NV}종').replace('575컬럼', '전 컬럼')
        L[i] = s
        n += 1
    if 'updated: 2026-09-14' in s:
        L[i] = s.replace('2026-09-14', '2026-10-03')
        n += 1
io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
print('changed', n)
