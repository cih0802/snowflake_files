# O276 참조 정리 §4 3단계 — A 분류 치환 (기본 dry-run · --apply 시 적용)
import io, os, re, sys, csv, difflib
from collections import Counter

ROOT = '/workspace'
HERE = os.path.join(ROOT, '_archive/O276_project_closure')
CLOSE = '_archive/O276_project_closure/'
RESTR = '_archive/RESTRUCTURE_20261031-pre/'
A_DIRS = ('50_handover/', '30_operate/', '10_design/', '20_build/', '60_share/')
# 접두 직전이 경로문자(/·영숫자·_)가 아니어야 한다 — 이미 치환된 경로·OS 경로·경로 중간 토큰 제외
LB = r'(?<![/\w.-])((?:\.\./)*)'
RULES = [
    (re.compile(LB + r'(80_인수인계_프로젝트완료)'), CLOSE),
    (re.compile(LB + r'(20_issue/)'), CLOSE),
    (re.compile(LB + r'(99_NEXT_SESSION-O)'), CLOSE + '99_NEXT_SESSION_조각/'),  # 조각 파일명만 쓴 경우
    (re.compile(LB + r'(99_NEXT_SESSION(?:\.md|_조각))'), CLOSE),
    (re.compile(LB + r'(40_worklog/)'), CLOSE),
    (re.compile(LB + r'(tmp/)'), CLOSE),
    (re.compile(LB + r'(999_temp)'), CLOSE),
    (re.compile(LB + r'(MOVE_MAP)'), RESTR),
    (re.compile(LB + r'(00_WORKSPACE_RESTRUCTURE_PLAN)'), RESTR),
]


def depth_prefix(rel_dots, prefix, path):
    # 상대 링크(../)는 루트 기준으로 정규화해 접두를 붙인다
    if rel_dots:
        up = '../' * path.count('/')
        return up + prefix
    return prefix


def is_A(path, cls):
    # [2026-11-02 사용자 승인] 보류분(코드 파일 · 00_guides · 70 · 90)까지 A 분류 전건 치환
    return cls == 'A'


def fix(line, path):
    for rx, prefix in RULES:
        line = rx.sub(lambda m: depth_prefix(m.group(1), prefix, path) + m.group(2), line)
    return line


rows = list(csv.DictReader(io.open(os.path.join(HERE, 'ref_lines.tsv'), encoding='utf-8'), delimiter='\t'))
files = sorted({r['file'] for r in rows if is_A(r['file'], r['class'])})
apply = '--apply' in sys.argv
if apply:
    sys.path.insert(0, os.path.join(ROOT, 'scripts'))
    import snapshot_util
    SNAP = os.path.join(HERE, '_snap_refA')
diff_out, stat = [], Counter()
for f in files:
    p = os.path.join(ROOT, f)
    src = io.open(p, encoding='utf-8').read()
    lines = src.splitlines(keepends=True)
    new = [fix(l, f) for l in lines]
    if new != lines:
        stat['files'] += 1
        stat['lines'] += sum(1 for a, b in zip(lines, new) if a != b)
        diff_out.extend(difflib.unified_diff(lines, new, 'a/' + f, 'b/' + f, n=0))
        if apply:
            arch = os.path.join(SNAP, os.path.dirname(f))  # 원 경로 구조를 그대로 둔다(롤백 대응)
            os.makedirs(arch, exist_ok=True)
            snapshot_util.snapshot(p, 'refA', label='O276-C', archive=arch, quiet=True)
            io.open(p, 'w', encoding='utf-8', newline='').write(''.join(new))
            stat['snap'] += 1
io.open(os.path.join(HERE, 'replace_A.diff'), 'w', encoding='utf-8').write(''.join(diff_out))
# 검증: 새로 붙인 경로가 실재하는가(글롭·중괄호·<자리표시자> 는 판정 제외)
TOK = re.compile(r'_archive/(?:O276_project_closure|RESTRUCTURE_20261031-pre)/[^`\s|)\]:,·\'"]+')
dead = Counter()
for l in diff_out:
    if l.startswith('+') and not l.startswith('+++'):
        for t in TOK.findall(l):
            if re.search(r'[*{<]', t):
                continue
            if not os.path.exists(os.path.join(ROOT, t.rstrip('.'))):
                dead[t] += 1
io.open(os.path.join(HERE, 'replace_A_dead.tsv'), 'w', encoding='utf-8').write(
    ''.join('%s\t%d\n' % kv for kv in dead.most_common()))
print('dead path tokens', len(dead), 'occurrences', sum(dead.values()))
print('A files scanned', len(files), dict(stat), 'APPLIED' if apply else 'DRY-RUN')
