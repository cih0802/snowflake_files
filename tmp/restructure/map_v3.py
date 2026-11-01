"""O275 4-B v3 — 80·85 를 고정 영역으로(사용자 결정 2026-10-31) → 두 매핑표에서 해당 행 제거. v2 스냅샷 선행."""
import csv, os, shutil, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
ARCH = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4B'
KEEP = ('80_인수인계_프로젝트완료 및 유지보수용/', '85_실제 인수인계 문서/')
HDR = ['old_path', 'new_path', 'old_order', 'action', 'reason']
for name in ('MOVE_MAP.csv', 'MOVE_MAP_files.csv'):
    p = f'{ROOT}/{name}'
    a, b = open(p, 'rb').read(), open(p, 'rb').read()
    assert a == b, '해시 불안정'
    print(snapshot(p, 'v2', label='O275', archive=ARCH, quiet=True))
    rows = list(csv.DictReader(open(p, encoding='utf-8-sig')))
    keep = [r for r in rows if not r['old_path'].startswith(KEEP)]
    tmp = p + '.tmpwrite'
    with open(tmp, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.DictWriter(fh, HDR)
        w.writeheader()
        w.writerows(keep)
    shutil.copyfile(tmp, p)
    os.remove(tmp)
    assert len(list(csv.DictReader(open(p, encoding='utf-8-sig')))) == len(keep)
    print(name, len(rows), '->', len(keep))
