"""O275 4-B v2 반영 — 루트 MOVE_MAP.csv(v1) 스냅샷 후 v2 최종본으로 교체 · MOVE_MAP_files.csv 신규."""
import csv, hashlib, os, shutil, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
D = f'{ROOT}/tmp/restructure'
ARCH = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4B'
DIFF = {  # 80 사본과 내용이 다른 stale 후보(80 = 95 정제본)
    '04_silver_design/08_SILVER_테이블DDL_20260714.sql',
    '30_output_share/20260826_아키텍처 지도 요약본.html',
}
os.makedirs(ARCH, exist_ok=True)
print(snapshot(f'{ROOT}/MOVE_MAP.csv', 'v1', label='O275', archive=ARCH, quiet=True))


def fix(src, dst):
    rows = list(csv.DictReader(open(src, encoding='utf-8-sig')))
    for r in rows:
        if r['old_path'] in DIFF:
            r['reason'] += ' · 내용 상이(80 = 95 정제본) → 작업 원본은 _archive 보존'
        elif r['action'] == 'archive' and r['old_path'].endswith(('ALTER.sql', '런북_20260722.md')):
            r['reason'] += ' · 내용 동일(SHA256)'
    tmp = dst + '.tmpwrite'
    with open(tmp, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.DictWriter(fh, ['old_path', 'new_path', 'old_order', 'action', 'reason'])
        w.writeheader()
        w.writerows(rows)
    shutil.copyfile(tmp, dst)
    os.remove(tmp)
    back = list(csv.DictReader(open(dst, encoding='utf-8-sig')))
    assert len(back) == len(rows), dst
    print(dst, len(rows))


fix(f'{D}/mm_summary_final.csv', f'{ROOT}/MOVE_MAP.csv')
fix(f'{D}/mm_files_final.csv', f'{ROOT}/MOVE_MAP_files.csv')
