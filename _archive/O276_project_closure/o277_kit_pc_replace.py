# O277 — 키트 세션 운영 경로를 `01_project_control/` 로 치환 (기본 dry-run · --apply)
# 사용: python3 o277_kit_pc_replace.py <kit 경로> [--apply]
# 🔴 재작성본 — 원본은 /tmp 에서 실행 중 샌드박스 재시작으로 유실됐다(2026-11-02). 규칙·제외 범위는 원본과 같다.
# 🔴 이 도구는 「지시문」과 「과거 기록」을 구별하지 못한다 ⇒ 적용 후 롤백본과 줄 단위 diff 를 읽고
#    사고 서술 · 근거 좌표(`20_issue/91_사고사례집.md §Cnn` 등)는 되돌린다(O277-B 에서 13곳 복원).
import os
import re
import sys

KIT = sys.argv[1]
apply = '--apply' in sys.argv
PC = '01_project_control'
SKIP_DIRS = ('_archive', '08_handover_templates', '11_project_template')
SKIP_FILES = ('00_INVENTORY.md', '03_init_ihcho_스킬_개발이력.md', 'kit_paths.py')
RULES = [
    (re.compile(r'(?<![\w/])20_issue(?![\w])'), PC),
    (re.compile(r'(?<![\w/])99_NEXT_SESSION(?=\.md|_조각)'), PC + '/99_NEXT_SESSION'),
    (re.compile(r'(?<![\w/])40_worklog(?![\w])'), PC + '/98_worklog'),
]
nf = nl = 0
for d, ds, fs in os.walk(KIT):
    rel = os.path.relpath(d, KIT)
    if rel.split(os.sep)[0] in SKIP_DIRS:
        ds[:] = []
        continue
    for f in fs:
        if f in SKIP_FILES or not f.endswith(('.py', '.md', '.sh', '.txt', '.csv', '.yml')):
            continue
        p = os.path.join(d, f)
        src = open(p, encoding='utf-8').read()
        out, ch = [], 0
        for i, line in enumerate(src.split('\n'), 1):
            o = line
            for rx, rep in RULES:
                o = rx.sub(rep, o)
            if o != line:
                ch += 1
                if not apply:
                    print('%s:%d\n  - %s\n  + %s' % (os.path.relpath(p, KIT), i, line.strip()[:150], o.strip()[:150]))
            out.append(o)
        if ch:
            nf += 1
            nl += ch
            new = '\n'.join(out)
            if p.endswith('.py'):
                compile(new, p, 'exec')  # 🔴 구문이 깨지면 쓰지 않는다
            if apply:
                open(p, 'w', encoding='utf-8', newline='').write(new)
print('%s files %d lines %d' % ('APPLIED' if apply else 'DRY-RUN', nf, nl))
