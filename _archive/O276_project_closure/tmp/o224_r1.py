# O224 R1 — 요건(회원 Agent 교차 결합) 실측: SV_ML_SPONSOR_RISK·SV_ML_MEMBER_RISK·SV_ML_INC_CAMPAIGN 구조 + MEMBER 스펙 제한 문구
import json, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
for sv in ['SV_ML_SPONSOR_RISK', 'SV_ML_MEMBER_RISK', 'SV_ML_INC_CAMPAIGN']:
    c.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.SERVING.{sv}')
    rows = c.fetchall()
    base = [r[4] for r in rows if r[0] == 'TABLE' and r[3] == 'BASE_TABLE_NAME']
    dims = sorted({(r[0], r[1]) for r in rows if r[0] in ('DIMENSION', 'FACT', 'METRIC')})
    print('==', sv, 'base', base)
    print('   ', [f'{k[0][0]}:{k[1]}' for k in dims])
c.execute('DESCRIBE AGENT GN_DW.SERVING.AGENT_MEMBER')
cols = [d[0] for d in c.description]
spec = json.loads(c.fetchone()[cols.index('agent_spec')])
txt = json.dumps(spec, ensure_ascii=False)
for pat in ['cross-fact', '교차', '차단', '직접 결합', 'sponsor_risk']:
    for m in re.finditer(pat, txt):
        print('MEMBER', pat, '|', txt[max(0, m.start()-120):m.end()+160].replace('\\n', ' '))
for t in spec['tools']:
    if t['tool_spec']['name'] in ('analyst_ml_sponsor_risk', 'analyst_ml_member_risk'):
        print('DESC', t['tool_spec']['name'], '|', t['tool_spec']['description'][:900])
