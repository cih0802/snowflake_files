# O258 · 라이브 Agent instructions 값 리터럴 추출 (DESCRIBE AGENT · 읽기 전용)
import json, re, io, csv, os, snowflake.connector
tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
cn = snowflake.connector.connect(host=os.environ.get('SNOWFLAKE_HOST'), account=os.environ.get('SNOWFLAKE_ACCOUNT'),
                                 authenticator='oauth', token=tok, warehouse='COMPUTE_WH', role='ACCOUNTADMIN')
cur = cn.cursor(snowflake.connector.DictCursor)
rows = []
for a in ['AGENT_EXECUTIVE', 'AGENT_MARKETING', 'AGENT_MEMBER']:
    cur.execute('DESCRIBE AGENT GN_DW.SERVING.%s' % a)
    d = cur.fetchone()
    spec = d.get('agent_spec') or d.get('AGENT_SPEC') or ''
    io.open('/workspace/tmp/o258/agent_spec_%s.json' % a, 'w', encoding='utf-8').write(spec)
    s = json.loads(spec) if spec.strip().startswith('{') else {}
    ins = s.get('instructions') or {}
    for k in ('orchestration', 'response', 'system'):
        t = ins.get(k) or ''
        for m in re.finditer(r"([A-Za-z_][A-Za-z0-9_]*)\s*(=|IN\s*\()\s*'([^']*[가-힣][^']*)'", t):
            rows.append([a, k, m.group(1), m.group(3)])
        for m in re.finditer(r"'([^'\n]{1,20}[가-힣][^'\n]{0,20})'", t):
            rows.append([a, k, '', m.group(1)])
with io.open('/workspace/tmp/o258/literals_agent.csv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh); w.writerow(['agent', 'section', 'column', 'literal']); w.writerows(rows)
import collections
print(len(rows), collections.Counter(r[0] for r in rows))
for r in rows:
    if r[2]: print(r)
print(sorted({r[3] for r in rows})[:120])
