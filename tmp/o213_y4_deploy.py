# O213-Y4 — 09_2_AGENT_버전업.sql 절차 집행([0]→[0-B]→[0-C]→[2]→[3]→[5]) · 단계별 판정 실패 시 중단
# Co-authored with CoCo
import io, os, re, sys
import snowflake.connector

F = '/workspace/05_SV-Agent_ai/09_2_AGENT_버전업.sql'
AG = ['AGENT_MEMBER', 'AGENT_EXECUTIVE', 'AGENT_MARKETING']
EXPECT = {'AGENT_MEMBER': 22, 'AGENT_EXECUTIVE': 12, 'AGENT_MARKETING': 20}
t = io.open(F, encoding='utf-8').read()
tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
c = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                authenticator='oauth', token=tok, role='GN_DW_ADMIN', warehouse='GN_DW_DEV_WH')
cu = c.cursor()


def stmt(start):
    i = t.index(start)
    if start.startswith('EXECUTE IMMEDIATE $$'):
        return t[i:t.index('$$;', i + len('EXECUTE IMMEDIATE $$')) + 2]
    q = False; j = i
    while j < len(t):
        ch = t[j]
        if ch == "'":
            q = not q
        elif ch == ';' and not q:
            return t[i:j]
        j += 1


# [0] 사전검증 — 0행 기대
cu.execute(stmt('WITH required AS ('))
bad = cu.fetchall()
print('[0] 라이브 부재 =', len(bad), bad)
assert not bad
# [0-B] 스테이지 동기화
for a in AG:
    cu.execute(f"""COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/{a}/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/{a}/'
  PATTERN = '.*agent_spec[.]yaml'""")
    print('[0-B]', a, cu.fetchall())
# [0-C] 대조
cu.execute(stmt('EXECUTE IMMEDIATE $$\nDECLARE\n  q_src'))
rows = cu.fetchall()
print('[0-C]', rows)
v = {r[0]: r[-1] for r in rows}
assert all(v.get(a) == 'OK' for a in AG), v
# [1] 롤백 기준 기록
for a in AG:
    cu.execute(f'show versions in agent GN_DW.SERVING.{a}')
    cols = [d[0] for d in cu.description]
    ds = [dict(zip(cols, r)) for r in cu.fetchall()]
    print('[1]', a, 'default =', [d['name'] for d in ds if str(d['is_default']).lower() == 'true'], 'live =', sum(1 for d in ds if d['name'] is None))
if '--apply' not in sys.argv:
    print('DRY — [2][3] 미실행'); sys.exit()
# [2] live 소진
cu.execute(stmt('EXECUTE IMMEDIATE $$\nDECLARE\n  res STRING'))
print('[2]', cu.fetchall())
# [3] 버전 발행
for a in AG:
    s = stmt(f'ALTER AGENT GN_DW.SERVING.{a}' + (' \n' if a == 'AGENT_MEMBER' else '\n'))
    cu.execute(s)
    print('[3]', a, cu.fetchall())
# [5] 검증
for a in AG:
    cu.execute(f'show versions in agent GN_DW.SERVING.{a}')
    cols = [d[0] for d in cu.description]
    ds = [dict(zip(cols, r)) for r in cu.fetchall()]
    dflt = [d for d in ds if str(d['is_default']).lower() == 'true']
    sp = dflt[0]['agent_spec'] or ''
    n = sp.count('tool_spec')
    print('[5]', a, dflt[0]['name'], 'tools', n, 'expect', EXPECT[a], 'O213' in sp, 'OK' if n == EXPECT[a] else 'MISMATCH')
