import io
p = '/workspace/05_SV-Agent_ai/05_1_SV_DDL_MEMBER_MONTHLY.sql'
L = io.open(p, encoding='utf-8').read().split('\n')
n = 0
for i in range(119, 136):
    if "''신규''" in L[i] or "''기존''" in L[i]:
        L[i] = L[i].replace("''신규''", "'신규'").replace("''기존''", "'기존'")
        n += 1
io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
print('fixed', n)
