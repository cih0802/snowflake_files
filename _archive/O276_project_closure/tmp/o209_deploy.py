# O209 X5 — 09_2 절차 실행기(1 Agent) · [0-B] COPY → [0-C] 크기 대조 → [2] live 소진 → [3] ADD VERSION → [5] 확인
# 사용: python3 tmp/o209_deploy.py AGENT_EXECUTIVE "<COMMENT>"
# Co-authored with CoCo
import sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
a, comment = sys.argv[1], sys.argv[2]
WS = f'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/{a}/'
ST = f'@GN_DW.OPS.AGENT_SPEC_STAGE/{a}/'
cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_DEV_WH')


def vers():
    cur.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{a}')
    cols = [c[0] for c in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


before = vers()
prev = [v['name'] for v in before if v.get('is_default') in (True, 'true')]
print('직전 default =', prev)
cur.execute(f"COPY FILES INTO {ST} FROM '{WS}' PATTERN = '.*agent_spec[.]yaml'")
for i in range(6):
    cur.execute(f"LIST '{WS}' PATTERN = '.*agent_spec[.]yaml'"); s = cur.fetchall()[0][1]
    cur.execute(f"LIST {ST} PATTERN = '.*agent_spec[.]yaml'"); d = cur.fetchall()[0][1]
    if s == d:
        break
    time.sleep(5); cur.execute(f"COPY FILES INTO {ST} FROM '{WS}' PATTERN = '.*agent_spec[.]yaml'")
print('크기 ws/stage =', s, d)
if s != d:
    sys.exit('SIZE_MISMATCH — 중단')
if any(v['name'] is None for v in before):
    cur.execute(f"ALTER AGENT GN_DW.SERVING.{a} COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)'"); print('live committed')
cur.execute(f"ALTER AGENT GN_DW.SERVING.{a} ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/{a}' COMMENT = %s", (comment,))
after = vers()
for v in after[-2:]:
    print(v['name'], v.get('is_default'), str(v.get('agent_spec', '')).count('tool_spec'))
