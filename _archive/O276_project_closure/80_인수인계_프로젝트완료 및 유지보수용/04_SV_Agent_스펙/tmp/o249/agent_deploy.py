# O249 — AGENT_MARKETING 버전업(LTV 상한 컬럼명 변경 반영) · 사용자 승인 2026-10-20 · 절차 = tmp/o246d/agent_deploy_d.py
import io, sys, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

import os
A = os.environ['AG']
WS = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/'
cn = conn()
cur = cn.cursor()
cur.execute('USE ROLE GN_DW_ADMIN')
cur.execute("COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/%s/ FROM '%s%s/' PATTERN = '.*agent_spec[.]yaml'" % (A, WS, A))
print('COPY', cur.fetchall())
cur.execute("LIST '%s%s/' PATTERN = '.*agent_spec[.]yaml'" % (WS, A))
src = cur.fetchall()[0][1]
cur.execute("LIST @GN_DW.OPS.AGENT_SPEC_STAGE/%s/ PATTERN = '.*agent_spec[.]yaml'" % A)
dst = cur.fetchall()[0][1]
print('VERIFY ws=%s stage=%s' % (src, dst))
if src != dst:
    sys.exit('size mismatch')
cur.execute('SHOW VERSIONS IN AGENT GN_DW.SERVING.%s' % A)
cols = [d[0] for d in cur.description]
rows = cur.fetchall()
print('BEFORE', [(r[cols.index('name')], r[cols.index('is_default')]) for r in rows[-2:]])
if any(r[cols.index('name')] is None for r in rows):
    cur.execute("ALTER AGENT GN_DW.SERVING.%s COMMIT COMMENT = 'live 소진(O249 버전업 직전 스냅샷)'" % A)
    print('LIVE_COMMIT')
cur.execute("ALTER AGENT GN_DW.SERVING.%s ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/%s' "
            "COMMENT = 'O249-B = 공통 예측 가드레일 ①ML→②비중배분→③부서수식→④추세 · 신규 SV 배선 · 사용자 승인'" % (A, A))
print('ADD_VERSION', cur.fetchall(), cur.sfqid)
cur.execute('SHOW VERSIONS IN AGENT GN_DW.SERVING.%s' % A)
cols = [d[0] for d in cur.description]
for r in cur.fetchall()[-2:]:
    print('  %s default=%s created=%s' % (r[cols.index('name')], r[cols.index('is_default')], r[cols.index('created_on')]))
cn.close()
