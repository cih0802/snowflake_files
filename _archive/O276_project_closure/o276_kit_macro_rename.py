# O276 2단계 — 키트 dbt 매크로의 gn_ 접두 제거(파일명 + 키트 안 참조 동시) · 기본 dry-run
import io, os, re, sys

KIT = '/workspace/_reuse_kit'
REN = {'gn_no_structural_alter': 'no_structural_alter',
       'gn_view_commented': 'view_commented',
       'gn_view_column_list': 'view_column_list'}
FILES = {'06_dbt_macros/gn_no_structural_alter.sql': '06_dbt_macros/no_structural_alter.sql',
         '06_dbt_macros/gn_view_commented.sql': '06_dbt_macros/view_commented.sql'}
SKIP = {'00_INVENTORY.md'}  # 복사 시점 기록 — 손대지 않는다
RX = re.compile(r'\b(%s)\b' % '|'.join(sorted(REN, key=len, reverse=True)))
apply = '--apply' in sys.argv
# 충돌 검사: 새 이름이 이미 키트에 있으면 중단
for new in FILES.values():
    if os.path.exists(os.path.join(KIT, new)):
        sys.exit('충돌: %s 이미 존재' % new)
tot = 0
for dp, _, fs in os.walk(KIT):
    for f in fs:
        if f in SKIP:
            continue
        p = os.path.join(dp, f)
        try:
            src = io.open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        out, n = RX.subn(lambda m: REN[m.group(1)], src)
        if n:
            tot += n
            print('%3d  %s' % (n, os.path.relpath(p, KIT)))
            if apply:
                io.open(p, 'w', encoding='utf-8', newline='').write(out)
if apply:
    for old, new in FILES.items():
        os.rename(os.path.join(KIT, old), os.path.join(KIT, new))
print('APPLIED' if apply else 'DRY-RUN', 'replacements', tot, 'renames', len(FILES))
