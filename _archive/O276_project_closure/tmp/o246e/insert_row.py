import io
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
row = ('| 🟢 **`O246-E`** — 운영계(ZL50263 · CHOIH) 1~51번 배포 기록 소급 반영 · R2-9 신설 '
       '(원 세션 2026-10-19 · 반영 2026-10-20 · TRIALADMIN(SR61467) · ㉡ · 원 라벨 O246-A 충돌 → 접미 E) '
       '| 🟢 지침 R2-9 · 문서실행순서_llm실행 §1 백필 제외 · 이력 089 · 인수인계 O0246-E · '
       '🔴 RBAC CHOIH·dbt PROD_20261019 는 운영계 전용이라 미반영(SR61467 CHOIH 0행 · 버전 1개) '
       '| 운영계 집행 결과는 원 기록만(라이브 미대조) '
       '| `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-E.md` |\n')
lines = io.open(p, encoding='utf-8').readlines()
assert not any('`O246-E`' in l for l in lines)
idx = next(i for i, l in enumerate(lines) if l.startswith('| 🟢 **`O245`**'))
lines.insert(idx, row)
io.open(p, 'w', encoding='utf-8').write(''.join(lines))
print('inserted at', idx + 1)
