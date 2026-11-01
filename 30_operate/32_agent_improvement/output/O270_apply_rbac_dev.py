"""O270 W6 — 48_RBAC_SOURCE_ACCESS.sql 블록 [1]~[3] 만 실행(개발계 · 사용자 승인 2026-10-29).
[4] 이후(주석 템플릿·회수·롤백)는 실행하지 않는다. 첫 오류에서 멈춘다.
🆕 [O272] 인자화 — 기본 = dry-run(접속 없음 · 문장 수만) · `--apply` 가 있어야 집행(MUTATES 계약)
  --file  대상 SQL(기본 05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql · 운영계 판 = 48_RBAC_SOURCE_ACCESS_ZL50263.sql)
  --role  실행 역할(기본 SECURITYADMIN)
  --until 이 표지 앞까지만 실행(기본 '-- [4] ')"""
import argparse, os, sys
ap = argparse.ArgumentParser()
ap.add_argument('--file', default='/workspace/05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql')
ap.add_argument('--role', default='SECURITYADMIN')
ap.add_argument('--until', default='-- [4] ')
ap.add_argument('--apply', action='store_true')
a = ap.parse_args()
src = open(a.file, encoding='utf-8').read()
if a.until not in src:
    sys.exit(f'FAIL 표지 {a.until!r} 가 {a.file} 에 없다 — 전체 실행을 막는다')
body = src.split(a.until)[0]
stmts = [l.strip() for l in body.splitlines() if l.strip() and not l.strip().startswith('--')]
if not a.apply:
    print('[dry-run]', a.file, '·', len(stmts), '문장 · 역할', a.role, '(집행 = --apply)')
    sys.exit(0)
import snowflake.connector
tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(host=os.environ.get('SNOWFLAKE_HOST'), account=os.environ.get('SNOWFLAKE_ACCOUNT'),
                                  authenticator='oauth', token=tok, role=a.role)
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
