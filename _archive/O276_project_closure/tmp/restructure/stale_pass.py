"""O275 4-B v2 후처리 — 폴더 간 중복까지 포함한 「날짜<20261001 중복 → stale」 판정.

규칙(사용자 결정 2026-10-31 + 해석):
  - 대상 = 파일명 날짜 < 20261001 · 동결 영역(_archive/_backup_*/조각) 밖.
  - 중복 = 동결 영역 밖 다른 위치(90 고정 영역 포함)에 ㉠ 날짜 제거 이름이 같거나 ㉡ 내용 SHA256 동일한 파일이 있다.
  - 🔴 보존 예외: 80·85 인수인계 납품물(00_INDEX 관리 · 4-C 본문 치환 금지 영역)과 90(고정)은 archive 하지 않는다
    → 그 사본이 있으면 작업 폴더 쪽 사본만 _archive 로 간다.
입력: mm_v2_files.csv  출력: mm_v2_files.csv · mm_v2.csv 갱신본(*_final.csv)
"""
import csv, hashlib, os, re
from collections import defaultdict

ROOT = '/workspace'
D = '/workspace/tmp/restructure'
CUTOFF = 20261001
DATE = re.compile(r'(?<!\d)(20\d{2})[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12]\d|3[01])(?!\d)')
FROZEN = re.compile(r'(^|/)(_archive|_backup_[^/]*|[^/]*_조각|__pycache__|target|logs)(/|$)')
KEEP = ('80_인수인계_프로젝트완료 및 유지보수용/', '85_실제 인수인계 문서/', '90_provided_definition/')


def sha(p):
    h = hashlib.sha256()
    with open(os.path.join(ROOT, p), 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def key(fn):
    stem, ext = os.path.splitext(fn)
    return re.sub(r'[\s_\-.()]+', '', DATE.sub('', stem).lower()) + ext.lower()


rows = list(csv.DictReader(open(f'{D}/mm_v2_files.csv', encoding='utf-8-sig')))
pool = [x['old_path'] for x in rows]
for dp, _, fns in os.walk(os.path.join(ROOT, '90_provided_definition')):
    pool += [os.path.relpath(os.path.join(dp, f), ROOT) for f in fns]
live = [p for p in pool if not FROZEN.search(p)]

cand = []
for p in live:
    m = DATE.search(p.rsplit('/', 1)[-1])
    if m and int(''.join(m.groups())) < CUTOFF and not p.startswith(KEEP):
        cand.append(p)
need_hash = set(cand)
by_key = defaultdict(list)
for p in live:
    by_key[key(p.rsplit('/', 1)[-1])].append(p)
    if os.path.getsize(os.path.join(ROOT, p)) in {os.path.getsize(os.path.join(ROOT, c)) for c in ()}:
        pass
size_of = {p: os.path.getsize(os.path.join(ROOT, p)) for p in live}
cand_sizes = {size_of[c] for c in cand}
hashes = {p: sha(p) for p in live if size_of[p] in cand_sizes}
by_sha = defaultdict(list)
for p, h in hashes.items():
    by_sha[h].append(p)

stale = {}
for c in cand:
    sib = [p for p in by_key[key(c.rsplit('/', 1)[-1])] if p != c]
    same = [p for p in by_sha.get(hashes.get(c), []) if p != c]
    if sib or same:
        stale[c] = ('이름 중복: ' + sib[0]) if sib else ('내용 동일: ' + same[0])

out, summ_add, n = [], [], 0
for x in rows:
    o = x['old_path']
    if x['action'] == 'archive' and o.startswith(KEEP):  # v2 의 80 내부 archive 판정 취소
        x['new_path'] = x['new_path'].replace('/_archive/', '/')
        x['action'], x['reason'] = 'move', '폴더 이동(80·85 납품물 보존 예외)'
    if o in stale and x['action'] != 'archive':
        d, fn = x['new_path'].rsplit('/', 1)
        x['new_path'] = f'{d}/_archive/{fn}'
        x['action'] = 'archive'
        x['reason'] = f'날짜<{CUTOFF} 중복 → stale · {stale[o]}'
        n += 1
    out.append(x)

hdr = ['old_path', 'new_path', 'old_order', 'action', 'reason']
with open(f'{D}/mm_files_final.csv', 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.DictWriter(fh, hdr)
    w.writeheader()
    w.writerows(out)
srows = [r for r in csv.DictReader(open(f'{D}/mm_v2.csv', encoding='utf-8-sig'))
         if not (r['action'] == 'archive' and r['old_path'].startswith(KEEP))]
have = {r['old_path'] for r in srows}
fix = {x['old_path']: x for x in out}
for r in srows:
    if r['old_path'] in fix and fix[r['old_path']]['action'] == 'archive':
        r.update(fix[r['old_path']])
srows += [x for x in out if x['action'] == 'archive' and x['old_path'] not in have]
with open(f'{D}/mm_summary_final.csv', 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.DictWriter(fh, hdr)
    w.writeheader()
    w.writerows(srows)
news = [x['new_path'] for x in out]
print('candidates', len(cand), 'stale', len(stale), 'archived', n, 'summary', len(srows), 'dup_new', len(news) - len(set(news)))
for c, why in sorted(stale.items()):
    print('ARCHIVE', c, '|', why)
for c in sorted(set(cand) - set(stale)):
    print('KEEP   ', c)
