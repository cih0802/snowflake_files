"""O275-A 잔존 정정.

㉠ archive 오판 2건 되돌림(현행 게이트 입력·생성기 출력): 08_SILVER_테이블DDL_20260714.sql · 20260826_아키텍처_지도_요약본.html
   → `_archive/` 에서 상위 폴더로 이동 + MOVE_MAP*.csv 행 정정(action=move).
㉡ scripts/ 잔존 옛 경로(RESIDUAL_PATHS.csv) 치환 — 해당 줄만 · 파일별 스냅샷 선행.
   A = `/workspace/OLD…` → MOVE_MAP_files 정확 일치 우선 · 없으면 폴더 접두 + 실재하는 공백 치환형
   B = 따옴표 안 basename(이름 변경분) → 새 basename
"""
import csv, hashlib, os, re, shutil, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot  # noqa: E402

ROOT = '/workspace'
ARCH = f'{ROOT}/_archive/RESTRUCTURE_20261031-pre/4C/residual'
os.makedirs(ARCH, exist_ok=True)
HDR = ['old_path', 'new_path', 'old_order', 'action', 'reason']
UNARCH = {
    '04_silver_design/08_SILVER_테이블DDL_20260714.sql': '10_design/12_silver_design/08_SILVER_테이블DDL_20260714.sql',
    '30_output_share/20260826_아키텍처 지도 요약본.html': '60_share/61_output_share/20260826_아키텍처_지도_요약본.html',
}
NOTE = ' · 🔴 O275-A 정정 = 현행 게이트 입력/생성기 출력 → archive 취소'


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def snap(p):
    nm = os.path.relpath(p, ROOT).replace('/', '__').replace(' ', '_') + '.O275-A-residual-pre'
    snapshot(p, 'pre', label='O275', archive=ARCH, name=nm, quiet=True)


# ㉠ 파일 되돌림 + 매핑표
for name in ('MOVE_MAP.csv', 'MOVE_MAP_files.csv'):
    p = f'{ROOT}/{name}'
    snap(p)
    rows = list(csv.DictReader(open(p, encoding='utf-8-sig')))
    for r in rows:
        if r['old_path'] in UNARCH and r['action'] == 'archive':
            src = f'{ROOT}/{r["new_path"]}'
            dst = f'{ROOT}/{UNARCH[r["old_path"]]}'
            if name == 'MOVE_MAP_files.csv' and os.path.exists(src) and not os.path.exists(dst):
                h = sha(src)
                shutil.copy2(src, dst)
                assert sha(dst) == h
                os.remove(src)
                print('unarchive', r['new_path'], '->', UNARCH[r['old_path']])
            r['new_path'], r['action'], r['reason'] = UNARCH[r['old_path']], 'move', r['reason'] + NOTE
    tmp = p + '.tmpwrite'
    with open(tmp, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.DictWriter(fh, HDR)
        w.writeheader()
        w.writerows(rows)
    shutil.copyfile(tmp, p)
    os.remove(tmp)
    assert len(list(csv.DictReader(open(p, encoding='utf-8-sig')))) == len(rows)

# ㉡ 경로 치환
files = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
fmap = {r['old_path']: r['new_path'] for r in files}
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
tops = {r['old_path'].rstrip('/'): r['new_path'].rstrip('/') for r in summ
        if r['old_path'].endswith('/') and '/' not in r['old_path'].rstrip('/')}
base = {os.path.basename(r['old_path']): os.path.basename(r['new_path']) for r in files
        if os.path.basename(r['old_path']) != os.path.basename(r['new_path'])}
A = re.compile(r'/workspace/(' + '|'.join(re.escape(t) for t in sorted(tops, key=len, reverse=True)) + r')((?:/[^\'"`\n]*)?)(?=[\'"`]|$)')


def fix_a(m):
    old_top, rest = m.group(1), m.group(2)
    full = old_top + rest
    if full in fmap:
        return '/workspace/' + fmap[full]
    new = tops[old_top] + rest
    cand = tops[old_top] + rest.replace(' ', '_')
    if ' ' in rest and os.path.exists(f'{ROOT}/{cand}'):
        new = cand
    return '/workspace/' + new


hits = list(csv.DictReader(open(f'{ROOT}/tmp/restructure/RESIDUAL_PATHS.csv', encoding='utf-8-sig')))
by_file = {}
for h in hits:
    by_file.setdefault(h['file'], set()).add(int(h['line']))
changed = 0
for rel, lines in sorted(by_file.items()):
    p = f'{ROOT}/{rel}'
    a, b = open(p, 'rb').read(), open(p, 'rb').read()
    assert a == b, f'해시 불안정 {rel}'
    text = a.decode('utf-8').split('\n')
    before = list(text)
    for i in lines:
        ln = text[i - 1]
        ln = A.sub(fix_a, ln)
        for ob, nb in base.items():
            for q in ('"', "'", '`'):
                ln = ln.replace(q + ob + q, q + nb + q)
        text[i - 1] = ln
    if text != before:
        snap(p)
        data = '\n'.join(text).encode('utf-8')
        with open(p, 'wb') as fh:
            fh.write(data)
        assert open(p, 'rb').read() == data
        changed += sum(1 for x, y in zip(before, text) if x != y)
        print('fixed', rel)
print('lines changed', changed)
