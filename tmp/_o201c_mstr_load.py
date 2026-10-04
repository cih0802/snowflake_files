#!/usr/bin/env python3
# O201-C — MSTR 최초 이력 적재(06_MSTR_적재_실행.sql [2]) · 결과를 파일로
import io, os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
cn = conn()
q('USE ROLE GN_DW_ADMIN', cn)
q('USE WAREHOUSE GN_DW_ETL_WH', cn)
t = time.time()
_, r = q("CALL GN_DW.MSTR.USP_RUN_MSTR_1ST('202601', 'POC', TRUE)", cn)
print('sec=%d' % (time.time() - t))
print(str(r[0][0])[:2000])
_, r = q("SELECT TABLE_NAME, ROW_COUNT FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='MSTR' AND TABLE_TYPE='BASE TABLE' ORDER BY 1", cn)
for x in r:
    print(x)
cn.close()
