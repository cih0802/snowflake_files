import io
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
row = io.open('/workspace/tmp/_o201c_index_row.txt', encoding='utf-8').read().rstrip('\n')
L = io.open(p, encoding='utf-8').read().split('\n')
i = next(k for k, l in enumerate(L) if l.startswith('| 🟢 **`O201-B`**'))
assert L[i - 1].startswith('|---'), L[i - 1]
L.insert(i, row)
io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
print('inserted at', i + 1)
