# O224 X1 — 라이브 기본 버전 ↔ 로컬 스펙 정본에 O223 표식 존재 대조(읽기 전용)
import io, json, os, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
cur = conn().cursor()
for ag in ['AGENT_EXECUTIVE', 'AGENT_MEMBER', 'AGENT_MARKETING']:
    cur.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{ag}')
    cols = [c[0] for c in cur.description]
    dv = [r[cols.index('name')] for r in cur.fetchall() if str(r[cols.index('is_default')]).lower() == 'true']
    cur.execute(f'DESCRIBE AGENT GN_DW.SERVING.{ag}')
    cols = [c[0] for c in cur.description]
    live = cur.fetchone()[cols.index('agent_spec')]
    p = f'/workspace/cortex_project/agents/{ag}/agent_spec.yaml'
    loc = io.open(p, encoding='utf-8').read() if os.path.exists(p) else ''
    print(ag, 'default', dv, '| live O223', live.count('O223'), '| local O223', loc.count('O223'), '| local 존재', bool(loc))
