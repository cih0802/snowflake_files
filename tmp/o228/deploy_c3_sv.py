#!/usr/bin/env python3
"""O228 ③ C3 SV 재배포 — c3_sv_diff.md 에 나온 SV 만 파일에서 CREATE OR ALTER 문 1개를 잘라 실행(O214 deploy 방식).
전후 대조 = SHOW SEMANTIC DIMENSIONS/FACTS/METRICS 개수 불변 · 배포 후 라이브 COMMENT 이슈ID 잔여 스캔.
사용: python3 tmp/o228/deploy_c3_sv.py [dry]   (jw08094 · GN_DW_ADMIN)
Co-authored with CoCo
"""
import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

DIFF = '/workspace/tmp/o228/c3_sv_diff.md'
src = io.open('/workspace/tmp/o227/fix_c3_col.py', encoding='utf-8').read()
ns = {}
exec(compile(src[:src.index('IDL =')], 'h', 'exec'), ns)
ID = ns['ID']
D = {'15': '/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/'}
pairs = sorted(set(re.findall(r'^### (\S+):\d+ (\w+)$', io.open(DIFF, encoding='utf-8').read(), re.M)))


def path(f):
    return (D['15'] if f == '05_MSTR_SV_DDL.sql' else '/workspace/05_SV-Agent_ai/') + f


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


def shape(cur, sv):
    return tuple(len(cur.execute(f'SHOW SEMANTIC {k} IN GN_DW.SERVING.{sv}').fetchall())
                 for k in ('DIMENSIONS', 'FACTS', 'METRICS'))


cur = conn().cursor()
cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ETL_WH')
cur.execute('USE DATABASE GN_DW'); cur.execute('USE SCHEMA SERVING')
dry = 'dry' in sys.argv
verify = 'verify' in sys.argv  # 👤 c3_sv_deploy.sql 실행 후 — 실행 없이 라이브 잔여 스캔만
bad = 0
print('대상 SV', len(pairs))
for f, sv in ([] if verify else pairs):
    stmt = cut(io.open(path(f), encoding='utf-8').read(), sv)
    try:
        before = shape(cur, sv)
        if dry:
            print(f'· {sv} ({f}) 전 {before} · 문 {len(stmt)}자')
            continue
        cur.execute(stmt)
        after = shape(cur, sv)
        ok = before == after
        bad += not ok
        print(f'{"🟢" if ok else "🔴"} {sv}: (dim,fact,metric) {before} → {after}')
    except Exception as e:  # noqa: BLE001
        bad += 1
        print(f'🔴 {sv}: {str(e)[:300]}')
if not dry:
    left = 0
    for _, sv in pairs:
        rows = cur.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.SERVING.{sv}').fetchall()
        for r in rows:
            if r[3] == 'COMMENT' and r[4] and re.search(r'\b' + ID + r'\b', r[4]):
                left += 1
                print('  잔여', sv, r[1], r[2], re.findall(r'\b' + ID + r'\b', r[4])[:3])
    print('라이브 COMMENT 잔여 이슈ID', left)
    bad += left > 0
print('FAIL', bad)
sys.exit(1 if bad else 0)
