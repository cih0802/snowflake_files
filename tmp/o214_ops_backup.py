#!/usr/bin/env python3
"""O214 — OPS.O213_* 임시 객체 DROP 전 보존(테이블 7 → CSV · 프로시저 5 → GET_DDL) + 행수 대조.
사용: python3 tmp/o214_ops_backup.py          # 보존만
      python3 tmp/o214_ops_backup.py --drop   # 보존·대조 PASS 후 DROP (R4-4-3 사용자 승인 2026-10-08)
Co-authored with CoCo
"""
import csv
import io
import os
import sys

import snowflake.connector

OUT = '/workspace/tmp/o214_ops_backup'
TABLES = ['O213_BRONZE_TO_SILVER', 'O213_CAT_INVENTORY', 'O213_LINEAGE_GAP', 'O213_TRACE_STATUS_T',
          'O213_Y2_FINAL', 'O213_Y2_JUDGE', 'O213_Y2_NAMEHIT']
PROCS = [('O213_PROFILE_SCHEMA', 'VARCHAR'), ('O213_TRACE_LINEAGE', ''), ('O213_TRACE_LINEAGE2', ''),
         ('O213_TRACE_STATUS', 'VARCHAR'), ('O213_TRACE_TEST', '')]

token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                  authenticator='oauth', token=token, role='ACCOUNTADMIN',
                                  warehouse='GN_DW_DEV_WH', database='GN_DW', schema='OPS')
cur = con.cursor()
os.makedirs(OUT, exist_ok=True)
ok = True
for t in TABLES:
    cur.execute(f'SELECT * FROM GN_DW.OPS.{t}')
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description]
    p = f'{OUT}/{t}.csv'
    with io.open(p, 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)
    with io.open(p, encoding='utf-8', newline='') as f:
        back = sum(1 for _ in csv.reader(f)) - 1
    live = cur.execute(f'SELECT COUNT(*) FROM GN_DW.OPS.{t}').fetchone()[0]
    flag = back == live == len(rows)
    ok &= flag
    print(('🟢' if flag else '🔴'), t, 'live', live, 'csv', back)
for name, sig in PROCS:
    ddl = cur.execute(f"SELECT GET_DDL('PROCEDURE', 'GN_DW.OPS.{name}({sig})')").fetchone()[0]
    io.open(f'{OUT}/{name}.sql', 'w', encoding='utf-8').write(ddl)
    print('🟢 proc', name, len(ddl))
if '--drop' in sys.argv:
    if not ok:
        sys.exit('🔴 보존 대조 실패 — DROP 하지 않는다')
    for t in TABLES:
        cur.execute(f'DROP TABLE GN_DW.OPS.{t}')
        print('DROP', t)
    for name, sig in PROCS:
        cur.execute(f'DROP PROCEDURE GN_DW.OPS.{name}({sig})')
        print('DROP', name)
con.close()
