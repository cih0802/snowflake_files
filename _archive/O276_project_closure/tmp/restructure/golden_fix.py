"""O275 골든 복원 — 4C 경로 치환이 기준선 '값'(20_issue 등 무치환 문서의 제목·행)까지 바꾼 오류 시정.

doc_headings.json · index_rows.json = 4C 이전 스냅샷(60_share 그룹 직전)으로 복원.
단, 이동된 문서(경로 키가 바뀐 문서)는 키를 새 경로로 · 그 문서 제목은 실제 본문과 같은 치환을 적용.
현재 판본은 덮기 전에 snapshot_util 로 보관(R1-7-10).
"""
import csv, json, os, re, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
PRE = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4C/60_share'
ARCH = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4C/golden_fix'
moved = {r['old_path']: r['new_path'] for r in csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig'))}
pairs = sorted({(r['old_path'].rstrip('/'), r['new_path'].rstrip('/'))
                for r in csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig'))
                if r['old_path'].endswith('/') or '/' not in r['old_path']}, key=lambda x: -len(x[0]))
BL, BR = r'(?<![\w/.\-])', r'(?=[/`\'"\s)\]|,:;>]|$)'


def subst(s):
    for o, n in pairs:
        s = re.sub(BL + re.escape(o) + BR, n, s)
    return s


os.makedirs(ARCH, exist_ok=True)
for name in ('doc_headings.json', 'index_rows.json'):
    cur = f'{ROOT}/scripts/golden/{name}'
    print(snapshot(cur, 'post4C', label='O275', archive=ARCH, quiet=True))
    orig = json.load(open(f'{PRE}/scripts__golden__{name}.O275-4C-pre', encoding='utf-8'))
    key = 'docs' if name == 'doc_headings.json' else 'rows'
    fixed = {}
    for k, v in orig[key].items():
        nk = moved.get(k, k)
        if nk != k:  # 이동된 문서 — 키만 새 경로로(본문은 치환 대상이 아니므로 값은 원문 유지)
            print('  remap', k, '->', nk)
        fixed[nk] = v
    orig[key] = fixed
    data = json.dumps(orig, ensure_ascii=False, indent=1)
    with open(cur, 'w', encoding='utf-8') as fh:
        fh.write(data)
    assert open(cur, encoding='utf-8').read() == data
    print(name, 'restored', len(fixed))
