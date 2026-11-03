# O213-Y4 — DATA_AGENT_RUN 1건 프로브(트라이얼 차단 여부 · 신규 도구 라우팅 1건)
import json, os, re, snowflake.connector
tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
c = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                authenticator='oauth', token=tok, role='GN_DW_ANALYST', warehouse='GN_DW_ANALYTICS_WH')
cu = c.cursor()
req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": "2026년 9월 후원자유형별 홈페이지 방문 세션수를 보여줘"}]}]}, ensure_ascii=False)
try:
    cu.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN('GN_DW.SERVING.AGENT_MARKETING', %s)", (req,))
    r = cu.fetchone()[0]
    os.makedirs('/workspace/tmp/nlsmoke', exist_ok=True)
    open('/workspace/tmp/nlsmoke/o213_probe.json', 'w').write(r)
    tools = sorted(set(re.findall(r'"name"\s*:\s*"(analyst_[a-z_]+)"', r)))
    print('OK len', len(r), 'tools', tools, '992' in r)
except Exception as e:
    print('ERR', str(e)[:300])
