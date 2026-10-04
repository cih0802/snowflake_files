#!/usr/bin/env python3
# O201-C — SV DDL 정본 파일 배포(CREATE OR ALTER 문 1개 + GRANT) · 사용: <ddl 파일> <SV 이름>
import io, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
path, sv = sys.argv[1], sys.argv[2]
L = io.open(path, encoding='utf-8').read().splitlines()
s = next(i for i, l in enumerate(L) if l.startswith('CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.%s' % sv))
e = next(i for i in range(s, len(L)) if L[i].rstrip().endswith("';") or L[i].strip() == ');')
ddl = '\n'.join(L[s:e + 1]).rstrip().rstrip(';')
grants = [l.rstrip(';') for l in L[e + 1:e + 10] if l.startswith('GRANT ')]
cn = conn()
q('USE ROLE GN_DW_ADMIN', cn)
q(ddl, cn)
for g in grants:
    q(g, cn)
_, r = q("SHOW SEMANTIC VIEWS LIKE '%s' IN SCHEMA GN_DW.SERVING" % sv, cn)
print('owner =', r[0][5], '· grants =', len(grants))
cn.close()
