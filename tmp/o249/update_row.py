import io
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
L = io.open(p, encoding='utf-8').readlines()
assert L == io.open(p, encoding='utf-8').readlines()
i = next(k for k, l in enumerate(L) if '**`O249`**' in l)
old = L[i]
assert old.count('| 🟡 스모크 5/5') == 1 and old.startswith('| 🟡 **`O249`**')
new = old.replace('| 🟡 **`O249`**', '| 🟢 **`O249`**', 1).replace('단위 O249-A)', '단위 O249-A · O249-B)', 1)
new = new.replace('| 🟡 스모크 5/5 · 상한 80 재현 · 축 합 일치 · 👤 잔여 = dbt build FMCS · A3 ㉠~㉤ 사람 확인 · 미연결 캠페인 1,608건 현업 송부 ',
                  '| 🟢 스모크 5/5 · 상한 80 재현(build 후 98행) · A3 차단 통과 · 🆕 B = 체크리스트 ⑤ 재적용(마스킹 12 · A2) · 캡처 15/15 · 생성기 4 · 80 패키지 MISSING 0 · DR-31 dim 시정 · 👤 잔여 = dim 3 build · 현업 회신 ', 1)
new = new.replace('`99_NEXT_SESSION_조각/99_NEXT_SESSION-O0249-A.md` |', '`99_NEXT_SESSION_조각/99_NEXT_SESSION-O0249-B.md` |', 1)
assert new != old
L[i] = new
io.open(p, 'w', encoding='utf-8').write(''.join(L))
print('updated line', i + 1)
