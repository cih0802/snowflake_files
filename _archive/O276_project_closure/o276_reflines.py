# O276 참조 정리 §4 1~2단계 — 행 단위 재추출 + A/B/C 분류 (읽기 전용)
import io, os, re, csv

ROOT = '/workspace'
HERE = os.path.join(ROOT, '_archive/O276_project_closure')
TARGETS = ['80_인수인계_프로젝트완료', '20_issue/', '99_NEXT_SESSION', 'tmp/',
           '40_worklog', 'MOVE_MAP', '00_WORKSPACE_RESTRUCTURE_PLAN', '999_temp']
TMP_RE = re.compile(r'(?<![/A-Za-z0-9_])tmp/')
SKIP_PREFIX = '_archive/O276_project_closure/'


def hits(line):
    out = []
    for t in TARGETS:
        if t == 'tmp/':
            if TMP_RE.search(line):
                out.append(t)
        elif t in line:
            # 이미 치환된 행(아카이브 접두 포함)은 제외
            if line.count(t) > line.count(SKIP_PREFIX + t) + line.count('RESTRUCTURE_20261031-pre/' + t):
                out.append(t)
    return out


def classify(path):
    if path.startswith('_archive/'):
        return 'B'
    if path.startswith('85_실제 인수인계 문서/'):
        return 'B'
    if path.startswith('10_dbt_pipeline/'):
        return 'B'
    if path.startswith('scripts/'):
        return 'C'
    if path.startswith('.snowflake/cortex/skills/init_ihcho/'):
        return 'C'
    if path == '00_WORKSPACE_MAP.md':
        return 'B'  # §0 갱신 완료 · §1~§3 은 조사 기록
    if path == '00_REFERENCE_CLEANUP_PLAN.md':
        return 'B'
    return 'A'


files = sorted({r[1] for r in csv.reader(io.open(os.path.join(HERE, '_refmatrix_pre.tsv'),
                encoding='utf-8'), delimiter='\t')} - {'source_file'})
rows, missing = [], []
for f in files:
    p = os.path.join(ROOT, f)
    if not os.path.isfile(p):
        missing.append(f)
        continue
    for i, line in enumerate(io.open(p, encoding='utf-8', errors='replace'), 1):
        h = hits(line)
        if h:
            rows.append((classify(f), f, i, ','.join(h), line.rstrip('\n')[:500]))

with io.open(os.path.join(HERE, 'ref_lines.tsv'), 'w', encoding='utf-8', newline='') as fp:
    w = csv.writer(fp, delimiter='\t')
    w.writerow(['class', 'file', 'line', 'targets', 'text'])
    w.writerows(rows)

from collections import Counter
print('files', len(files), 'missing', len(missing), 'rows', len(rows))
print(Counter(r[0] for r in rows))
print(Counter((r[0], r[1].split('/')[0]) for r in rows).most_common(40))
print('missing:', missing[:20])
