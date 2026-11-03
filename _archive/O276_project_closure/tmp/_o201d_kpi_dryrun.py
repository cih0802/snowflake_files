#!/usr/bin/env python3
# O201-D — SV_MEMBER_MONTHLY_KPI DDL 사전 검증: OPS 에 임시 뷰·SV 를 만들고 스모크 후 삭제
import io, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
m = io.open(os.path.join(ROOT, '10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_MONTHLY_KPI.sql'), encoding='utf-8').read()
m = re.sub(r"\{\{ ref\('(\w+)'\) \}\}", r'GN_DW.GOLD.\1', m)
s = io.open(os.path.join(ROOT, '05_SV-Agent_ai/05_14_SV_DDL_MEMBER_MONTHLY_KPI.sql'), encoding='utf-8').read()
a = s.index('\nCREATE OR ALTER SEMANTIC VIEW') + 1; b = s.index("';", s.index('  COMMENT = \'회원 활동율', a)) + 1
sv = s[a:b].replace('GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI', 'GN_DW.OPS.ZZ_TMP_SV_KPI') \
            .replace('GN_DW.GOLD.WIDE_MEMBER_MONTHLY_KPI', 'GN_DW.OPS.ZZ_TMP_KPI_V')
cn = conn()
q('USE ROLE GN_DW_ADMIN', cn); q('USE WAREHOUSE GN_DW_ETL_WH', cn)
try:
    q('CREATE OR REPLACE VIEW GN_DW.OPS.ZZ_TMP_KPI_V AS ' + m, cn)
    q(sv, cn)
    _, r = q("SELECT * FROM SEMANTIC_VIEW(GN_DW.OPS.ZZ_TMP_SV_KPI METRICS kpi.ACTIVE_RATE, kpi.ACTIVE_RATE_NEW, kpi.ACTIVE_RATE_EXISTING, kpi.DEV_CUM_AMT_CNT_SUM DIMENSIONS kpi.MONTH_KEY) WHERE MONTH_KEY IN (202512, 202601) ORDER BY MONTH_KEY", cn)
    for x in r:
        print(x)
finally:
    q('DROP SEMANTIC VIEW IF EXISTS GN_DW.OPS.ZZ_TMP_SV_KPI', cn)
    q('DROP VIEW IF EXISTS GN_DW.OPS.ZZ_TMP_KPI_V', cn)
    print('cleanup done')
cn.close()
