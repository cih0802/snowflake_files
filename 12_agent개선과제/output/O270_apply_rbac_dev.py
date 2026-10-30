"""O270 W6 — 48_RBAC_SOURCE_ACCESS.sql 블록 [1]~[3] 만 실행(개발계 · 사용자 승인 2026-10-29).
[4] 이후(주석 템플릿·회수·롤백)는 실행하지 않는다. 첫 오류에서 멈춘다."""
import os, sys
import snowflake.connector
src = open('/workspace/05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql', encoding='utf-8').read()
body = src.split('-- [4] ')[0]
stmts = [l.strip() for l in body.splitlines() if l.strip() and not l.strip().startswith('--')]
tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(host=os.environ.get('SNOWFLAKE_HOST'), account=os.environ.get('SNOWFLAKE_ACCOUNT'),
                                  authenticator='oauth', token=tok, role='SECURITYADMIN')
cur = con.cursor()
ok = 0
for s in stmts:
    try:
        cur.execute(s.rstrip(';'))
        ok += 1
    except Exception as e:
        print('FAIL', ok + 1, s, '\n', e)
        sys.exit(1)
print('OK', ok, 'of', len(stmts))
