#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O169 축1 원문 덤프 — 게이트의 판정 함수를 그대로 import 한다(J8 「분모를 하나로」).

🔴 내 문자열 카운트로 세지 않는다: 순수 count 는 71, 게이트 LIVE 판정은 68 이었다
   (차 3 = `qualified()` 가 병기·개명선언으로 면제한 출현).
"""
import io
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import rename_stale_gate as G  # noqa: E402

hits, ok, scanned = G.scan()
live = hits['LIVE']

by_file = {}
for rel, lineno, name in live:
    by_file.setdefault(rel, []).append((lineno, name))

print('스캔 %d파일 · 면제 %d · 축1 %d건 / %d파일' % (scanned, ok, len(live), len(by_file)))
print('')

cache = {}
for rel in sorted(by_file, key=lambda r: (-len(by_file[r]), r)):
    rows = sorted(by_file[rel])
    if rel not in cache:
        cache[rel] = io.open(os.path.join(G.ROOT, rel),
                             encoding='utf-8', errors='replace').read().split('\n')
    body = cache[rel]
    print('### %s  (%d건)' % (rel, len(rows)))
    seen = set()
    for lineno, name in rows:
        if lineno in seen:
            continue
        seen.add(lineno)
        txt = body[lineno - 1].strip()
        if len(txt) > 900:
            txt = txt[:900] + ' …[절단]'
        print('  :%d  %s' % (lineno, txt))
    print('')
