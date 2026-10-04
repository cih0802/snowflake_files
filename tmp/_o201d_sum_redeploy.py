#!/usr/bin/env python3
# O201-D — 04 의 USP_F_MM_SPNSR_DVLP_SUM 1개만 배포 → 202601 재계산 → 체크섬 대조
import io, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
s = io.open(os.path.join(ROOT, '15_MSTR 이관 PoC', 'snowflake 적용 ddl', '04_sp_script.sql'), encoding='utf-8').read()
a = s.index('CREATE OR REPLACE PROCEDURE GN_DW.MSTR.USP_F_MM_SPNSR_DVLP_SUM(')
b = s.index('$$;', s.index('$$', s.index('AS\n$$', a) + 4)) + 2
ddl = s[a:b]
assert 'BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT' in ddl
cn = conn()
q('USE ROLE GN_DW_ADMIN', cn); q('USE WAREHOUSE GN_DW_ETL_WH', cn)
q(ddl, cn)
_, r = q("CALL GN_DW.MSTR.USP_F_MM_SPNSR_DVLP_SUM('202601', 'POC')", cn)
print('call =', str(r[0][0])[:200])
_, r = q("SELECT COUNT(*), HASH_AGG(*), HASH_AGG(SPNSR_NO, SPNSR_BSNS_NO, SER_NO, OCCRRNC_DE, SPNSR_AMT2_CD) FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM WHERE STRD_MT='202601'", cn)
print('after =', r[0])
cn.close()
