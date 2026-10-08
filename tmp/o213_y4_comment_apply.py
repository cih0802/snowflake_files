# O213-Y4 — 09_1 [5] 의 ALTER AGENT … SET 3문장을 정본에서 잘라 실행
import io, os, re, snowflake.connector
t = io.open('/workspace/05_SV-Agent_ai/09_1_AGENT_생성.sql', encoding='utf-8').read()
i = t.index('-- [5] COMMENT·PROFILE 갱신')
sec = t[i:t.index('-- [6] 검증', i)]
stmts = re.findall(r"(ALTER AGENT GN_DW\.SERVING\.AGENT_\w+ SET\n  COMMENT = '.*?',\n  PROFILE = '.*?');", sec, re.S)
assert len(stmts) == 3, len(stmts)
tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
c = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                authenticator='oauth', token=tok, role='GN_DW_ADMIN', warehouse='GN_DW_DEV_WH')
cu = c.cursor()
for s in stmts:
    cu.execute(s); print(s.split()[2], cu.fetchone())
cu.execute('show agents in schema GN_DW.SERVING')
for r in cu.fetchall():
    print(r[1], ('홈페이지 방문' in r[5]) or ('지출결의' in r[5]) or ('청구 처리' in r[5]))
