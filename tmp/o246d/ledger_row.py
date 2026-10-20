import io, hashlib
p = '20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
raw = io.open(p, encoding='utf-8', newline='').read()
L = raw.split('\n')
i = 104
assert L[i].startswith('| 🟢 **`O246`**'), L[i][:40]
n0 = L[i].count('|')
r = L[i]
r = r.replace('단위 O246-A · O246-B · O246-C)', '단위 O246-A · O246-B · O246-C · O246-D)')
r = r.replace('Agent 3종 VERSION$7 |', 'SV_ML_MEMBER_RISK·CHURN_CAMPAIGN·SPONSOR_RISK(COMMENT) · Agent 3종 VERSION$8 |')
r = r.replace('지혜님 회신 완료 |', '지혜님 회신 완료 · D = D1 1회 출력·D2 대체 축·폴백 각주 패치 · 공112 현행 유지 확정 · dbt build 완료 |')
r = r.replace('잔여 = 결함 D1·D2 · R1 폴백 각주 미표기 · ', '잔여 = VERSION$8 스모크·eval(사용자) · ')
r = r.replace('`99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-C.md`', '`99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-D.md`')
assert r.count('|') == n0 and r != L[i] and len(r) <= 1900, (r.count('|'), n0, len(r))
for t in ['O246-D)', 'VERSION$8 |', '공112 현행 유지', 'O0246-D.md', 'VERSION$8 스모크']:
    assert t in r, t
L[i] = r
io.open(p, 'w', encoding='utf-8', newline='').write('\n'.join(L))
b = io.open(p, encoding='utf-8').read().split('\n')[i]
print('ok', len(b), b == r)
