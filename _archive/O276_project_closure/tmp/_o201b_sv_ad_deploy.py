#!/usr/bin/env python3
# O201-B — 05_7 SV_AD 정본 DDL(12~119행 CREATE OR ALTER) + GRANT 3 배포 · GN_DW_ADMIN
import io, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
L = io.open(os.path.join(ROOT, '05_SV-Agent_ai', '05_7_SV_DDL_AD.sql'), encoding='utf-8').read().splitlines()
s = next(i for i, l in enumerate(L) if l.startswith('CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD'))
e = next(i for i in range(s, len(L)) if L[i].strip() == ');')
ddl = '\n'.join(L[s:e + 1]).rstrip(';')
grants = [l.rstrip(';') for l in L[e + 1:e + 8] if l.startswith('GRANT ')]
assert len(grants) == 3, grants
cn = conn()
q('USE ROLE GN_DW_ADMIN', cn)
q(ddl, cn)
for g in grants:
    q(g, cn)
_, r = q("SHOW SEMANTIC VIEWS LIKE 'SV_AD' IN SCHEMA GN_DW.SERVING", cn)
print('owner =', r[0][5])
_, d = q("SELECT GET_DDL('SEMANTIC_VIEW','GN_DW.SERVING.SV_AD')", cn)
print('O201-B 표지 수 =', d[0][0].count('[O201-B]'))
cn.close()
