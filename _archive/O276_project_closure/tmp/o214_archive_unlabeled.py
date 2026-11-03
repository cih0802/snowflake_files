#!/usr/bin/env python3
"""O214 — `_archive/` UNLABELED 스냅샷 정리(R1-7-7 개별 삭제 · R4-4-3 사용자 승인 2026-10-08).

보존 규칙: ㉠ 원본 파일(기저 이름)마다 **가장 최근 1개** 보존 ㉡ 정본(20_issue · 99_NEXT_SESSION_조각 ·
00_guides · scripts)에 **파일명이 인용된 것** 보존. 나머지만 개별 삭제한다.
사용: python3 tmp/o214_archive_unlabeled.py           # 목록·판정만(tmp/o214_archive_unlabeled.tsv)
      python3 tmp/o214_archive_unlabeled.py --apply   # 개별 삭제 + 사후 os.listdir 재확인
Co-authored with CoCo
"""
import io
import os
import sys

A = '/workspace/_archive'
ROOTS = ['/workspace/20_issue', '/workspace/99_NEXT_SESSION_조각', '/workspace/00_guides', '/workspace/scripts']
names = sorted(f for f in os.listdir(A) if '.UNLABELED' in f)
ref = set()
corpus = []
for r in ROOTS:
    for dp, _, fs in os.walk(r):
        for f in fs:
            if f.endswith(('.md', '.py', '.sql', '.yml', '.txt', '.json')):
                try:
                    corpus.append(io.open(os.path.join(dp, f), encoding='utf-8', errors='ignore').read())
                except OSError:
                    pass
blob = '\n'.join(corpus)
for n in names:
    if n in blob:
        ref.add(n)
newest = {}
for n in names:
    base = n.split('.UNLABELED')[0]
    m = os.path.getmtime(os.path.join(A, n))
    if base not in newest or m > newest[base][0]:
        newest[base] = (m, n)
keep_new = {v[1] for v in newest.values()}
rows, dele = [], []
for n in names:
    why = 'keep_ref' if n in ref else ('keep_newest' if n in keep_new else 'delete')
    rows.append((n, why, os.path.getsize(os.path.join(A, n))))
    if why == 'delete':
        dele.append(n)
with io.open('/workspace/tmp/o214_archive_unlabeled.tsv', 'w', encoding='utf-8') as f:
    f.write('name\tdecision\tbytes\n')
    for r in rows:
        f.write('\t'.join(map(str, r)) + '\n')
print('total', len(names), 'keep_ref', len(ref), 'keep_newest', len(keep_new - ref),
      'delete', len(dele), 'bytes', sum(r[2] for r in rows if r[1] == 'delete'))
if '--apply' in sys.argv:
    for n in dele:
        os.remove(os.path.join(A, n))
    left = set(os.listdir(A))
    still = [n for n in dele if n in left]
    kept = [r[0] for r in rows if r[1] != 'delete' and r[0] not in left]
    print('deleted', len(dele) - len(still), 'still_present', len(still), 'kept_missing', len(kept))
