import os, io, json, sys
import snowflake.connector

q = sys.argv[1]
tok = io.open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ['SNOWFLAKE_HOST'],
                                  authenticator='oauth', token=tok, warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE'))
body = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": q}]}]}, ensure_ascii=False)
cur = con.cursor()
cur.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN('GN_DW.SERVING.AGENT_MARKETING', %s)", (body,))
raw = cur.fetchone()[0]
io.open('/workspace/tmp/o225/agent_raw.json', 'w', encoding='utf-8').write(raw)
r = json.loads(raw)
for c in r.get('content', []):
    t = c.get('type')
    if t == 'tool_use':
        print('TOOL', c['tool_use'].get('name'))
    elif t == 'tool_result':
        for x in c['tool_result'].get('content', []):
            j = x.get('json') or {}
            if 'sql' in j:
                print('SQL', j['sql'][:900])
    elif t == 'text':
        print('TEXT', c.get('text', ''))
