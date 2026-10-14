#!/usr/bin/env python3
"""O227 C3 테이블 컬럼(GOLD · WIDE_ 제외) — 06_DDL.sql 정본 문안을 라이브 ALTER(기본 dry-run).
Co-authored with CoCo"""
import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

G = '/workspace/03_top-down_gold/06_DDL.sql'
GL = io.open(G, encoding='utf-8').read().split('\n')
rows = [l.split('\t')[:2] for l in io.open('/workspace/tmp/o227/c3_col.tsv', encoding='utf-8')]
rows = [r for r in rows if not r[0].startswith('WIDE_')]
tstart = {}
for i, s in enumerate(GL):
    m = re.match(r'CREATE OR REPLACE (?:TRANSIENT )?TABLE GN_DW\.GOLD\.(\w+)', s)
    if m:
        tstart[m.group(1)] = i
cur = conn().cursor() if '--apply' in sys.argv else None
for obj, col in rows:
    k = next(k for k in range(tstart[obj], tstart[obj] + 400) if re.match(r'\s+' + col + r'\s', GL[k]))
    lit = re.search(r"COMMENT '((?:[^']|'')*)'", GL[k]).group(1)
    print(obj, col, len(lit))
    if cur:
        cur.execute(f"ALTER TABLE GN_DW.GOLD.{obj} MODIFY COLUMN {col} COMMENT '{lit}'")
print(len(rows), 'APPLIED' if cur else 'DRY-RUN')
