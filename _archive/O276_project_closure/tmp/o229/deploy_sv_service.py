#!/usr/bin/env python3
"""O229 SV_SERVICE 재배포 — 05_04 파일에서 CREATE OR ALTER 문 1개를 잘라 실행 · 전후 (dim,fact,metric) 대조.
사용: python3 tmp/o229/deploy_sv_service.py [dry]   (jw08094 · GN_DW_ADMIN)
Co-authored with CoCo
"""
import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

F = '/workspace/05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql'
SV = 'SV_SERVICE'
DIM_DELTA = 1
# 🆕 O229 D9 — 인자 = <파일> <SV> <기대 dim 증분>(생략 시 종전 SV_SERVICE · +1)
_a = [x for x in sys.argv[1:] if x != 'dry']
if len(_a) == 3:
    F, SV, DIM_DELTA = '/workspace/05_SV-Agent_ai/' + _a[0], _a[1], int(_a[2])


def cut(t, sv):
    m = re.search(r'CREATE OR (?:REPLACE|ALTER) SEMANTIC VIEW GN_DW\.SERVING\.' + sv + r'\b', t)
    q, j = False, m.start()
    while j < len(t):
        if t[j] == "'":
            q = not q
        elif t[j] == ';' and not q:
            return t[m.start():j]
        j += 1
    return t[m.start():]


def shape(cur):
    return tuple(len(cur.execute(f'SHOW SEMANTIC {k} IN GN_DW.SERVING.{SV}').fetchall())
                 for k in ('DIMENSIONS', 'FACTS', 'METRICS'))


cur = conn().cursor()
for s in ('USE ROLE GN_DW_ADMIN', 'USE WAREHOUSE GN_DW_ETL_WH', 'USE DATABASE GN_DW', 'USE SCHEMA SERVING'):
    cur.execute(s)
stmt = cut(io.open(F, encoding='utf-8').read(), SV)
before = shape(cur)
print('전', before, '문', len(stmt), '자')
if 'dry' in sys.argv:
    sys.exit(0)
try:
    cur.execute(stmt)
except Exception as e:  # noqa: BLE001
    print('🔴', str(e)[:400])
    sys.exit(1)
after = shape(cur)
ok = after == (before[0] + DIM_DELTA, before[1], before[2])
print('🟢' if ok else '🔴', '후', after, f'(기대 = dim +{DIM_DELTA})')
sys.exit(0 if ok else 1)
