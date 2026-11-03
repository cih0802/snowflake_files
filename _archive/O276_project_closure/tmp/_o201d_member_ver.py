import json, os, sys
sys.path.insert(0, 'scripts')
from sfconn import conn, q
cn = conn()
W = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/AGENT_MEMBER/'
for s in ['USE ROLE GN_DW_ADMIN',
          "COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MEMBER/ FROM '%s' FILES=('agent_spec.yaml')" % W,
          'ALTER AGENT GN_DW.SERVING.AGENT_MEMBER COMMIT',
          'ALTER AGENT GN_DW.SERVING.AGENT_MEMBER ADD VERSION FROM @GN_DW.OPS.AGENT_SPEC_STAGE/AGENT_MEMBER/']:
    try: q(s, cn); print('OK', s[:60])
    except Exception as e: print('ERR', s[:60], str(e)[:200])
c, r = q('DESCRIBE AGENT GN_DW.SERVING.AGENT_MEMBER', cn)
d = dict(zip([x.lower() for x in c], r[0])); sp = json.loads(d['agent_spec'])
print('default=', d['default_version_name'], 'kpi_tool=', any(t['tool_spec']['name']=='analyst_member_monthly_kpi' for t in sp['tools']), 'ntools=', len(sp['tools']))
