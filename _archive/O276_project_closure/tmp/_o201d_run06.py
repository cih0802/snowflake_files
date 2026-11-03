#!/usr/bin/env python3
# O201-D — 06 [2] 블록(EXECUTE IMMEDIATE) 을 파일에서 그대로 떼어 개발계에서 실행 · 소요 측정
import io, os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
s = io.open(os.path.join(ROOT, '15_MSTR 이관 PoC', 'snowflake 적용 ddl', '06_MSTR_적재_실행.sql'), encoding='utf-8').read()
a = s.index('EXECUTE IMMEDIATE $$')
b = s.index('$$;', a + 25) + 2
blk = s[a:b]
cn = conn()
q('USE ROLE GN_DW_ADMIN', cn); q('USE WAREHOUSE GN_DW_ETL_WH', cn)
t = time.time()
_, r = q(blk, cn)
print('sec=%d' % (time.time() - t))
print(str(r[0][0])[:1500])
_, r = q("SELECT STRD_MT, COUNT(*) FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM GROUP BY 1 ORDER BY 1", cn)
print(r)
cn.close()
