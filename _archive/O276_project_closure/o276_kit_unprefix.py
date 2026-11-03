# O276 2단계 — 키트 사본에서 1단계 링크 치환 접두를 걷어 관례 레이아웃 경로로 되돌린다(기본 dry-run)
#   사유: 키트는 1단계 적용 뒤 복사됐다 ⇒ `_archive/O276_project_closure/20_issue/…` 같은 이 프로젝트 전용 경로가 실렸다.
#   새 프로젝트에서는 `20_issue/…` 가 정답이다(kit_paths 관례 레이아웃).
import io, os, sys
from collections import Counter

KIT = '/workspace/_reuse_kit'
PREFIX = ['_archive/O276_project_closure/', '_archive/RESTRUCTURE_20261031-pre/']
SKIP = {'00_INVENTORY.md', '01_PLACEHOLDERS.md',
        # 이 프로젝트 아카이브를 의도적으로 가리키는 안내문(원본 출처 · O276 각주) — 걷으면 문장이 깨진다
        '91_사고사례집.md', 'README_운영도구.md', '00_INDEX_산출물목록.md'}
apply = '--apply' in sys.argv
c = Counter()
for dp, _, fs in os.walk(KIT):
    for f in fs:
        if f in SKIP:
            continue
        p = os.path.join(dp, f)
        if p == os.path.join(KIT, '00_README.md'):  # 키트 안내문 = 원래 값을 설명한다
            continue
        try:
            s = io.open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        o = s
        for pre in PREFIX:
            o = o.replace(pre, '')  # `…/99_NEXT_SESSION_조각/X` 도 관례 경로 그대로 남는다
        if o != s:
            n = sum(s.count(x) for x in PREFIX)
            c[os.path.relpath(p, KIT)] = n
            if apply:
                if p.endswith('.py'):
                    compile(o, p, 'exec')
                io.open(p, 'w', encoding='utf-8', newline='').write(o)
for k, v in sorted(c.items()):
    print('%4d  %s' % (v, k))
print('APPLIED' if apply else 'DRY-RUN', 'files', len(c), 'occurrences', sum(c.values()))
