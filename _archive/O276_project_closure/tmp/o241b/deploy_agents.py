# O241-F/T — Agent 3종 버전업(09_2 절차 그대로: COPY FILES → live 소진 → ADD VERSION) · Co-authored with CoCo
import sys
sys.path.insert(0, sys.path[0] + '/../../scripts')
from sfconn import conn
c = conn().cursor()
for s in ('USE ROLE GN_DW_ADMIN', 'USE WAREHOUSE GN_DW_DEV_WH'):
    c.execute(s)
WS = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/'
for a in ('AGENT_MEMBER', 'AGENT_EXECUTIVE', 'AGENT_MARKETING'):
    c.execute(f"COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/{a}/ FROM '{WS}{a}/' PATTERN = '.*agent_spec[.]yaml'")
    c.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{a}')
    cols = [d[0] for d in c.description]; rows = c.fetchall()
    if any(r[cols.index('name')] is None for r in rows):
        c.execute(f"ALTER AGENT GN_DW.SERVING.{a} COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)'"); print(a, 'live committed')
    before = [r[cols.index('name')] for r in rows]
    c.execute(f"ALTER AGENT GN_DW.SERVING.{a} ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/{a}'")
    c.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{a}')
    cols = [d[0] for d in c.description]
    print(a, 'before', before, 'after', [(r[cols.index('name')], r[cols.index('is_default')]) for r in c.fetchall()])
    c.execute(f'DESCRIBE AGENT GN_DW.SERVING.{a}')
    cols = [d[0] for d in c.description]; sp = c.fetchone()[cols.index('agent_spec')]
    print(a, 'O241-F' in sp, 'O241-T' in sp)
