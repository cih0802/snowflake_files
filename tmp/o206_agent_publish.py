# O206 — Agent 버전업 러너 (09_2 [0]→[0-B]→[2]→[3]→[5] · 인자로 받은 Agent 만)
# 사용: python3 tmp/o206_agent_publish.py AGENT_MEMBER AGENT_EXECUTIVE ...
# Co-authored with CoCo
import io, re, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

WS = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/'
agents = sys.argv[1:]
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_DEV_WH')

# [0] 사전검증 — 09_2 의 required 목록 블록을 그대로 실행
src = io.open('/workspace/05_SV-Agent_ai/09_2_AGENT_버전업.sql', encoding='utf-8').read()
m = re.search(r'WITH required AS \(.*?ORDER BY r\.AGENT_NAME, r\.SV_NAME;', src, re.S)
c.execute(m.group(0).rstrip(';'))
miss = [r for r in c.fetchall() if r[0] in agents]
print('[0] 라이브 부재 SV =', len(miss), miss)
if miss:
    sys.exit(1)

for a in agents:
    # [0-B] 동기화 + 크기 대조
    c.execute(f"COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/{a}/ FROM '{WS}{a}/' PATTERN = '.*agent_spec[.]yaml'")
    c.execute(f"LIST '{WS}{a}/' PATTERN = '.*agent_spec[.]yaml'"); ws = c.fetchall()[0][1]
    c.execute(f"LIST @GN_DW.OPS.AGENT_SPEC_STAGE/{a}/ PATTERN = '.*agent_spec[.]yaml'"); st = c.fetchall()[0][1]
    print(f'[0-B] {a} ws={ws} stage={st}', 'OK' if ws == st else '🔴 SIZE_MISMATCH')
    if ws != st:
        sys.exit(2)
    # [2] live 선소진
    c.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{a}')
    rows = c.fetchall(); cols = [d[0] for d in c.description]
    before = [r[cols.index('name')] for r in rows if r[cols.index('is_default')] in (True, 'true')]
    if any(r[cols.index('name')] is None for r in rows):
        c.execute(f"ALTER AGENT GN_DW.SERVING.{a} COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)'")
        print(f'[2] {a} live committed')
    # [3] 발행
    c.execute(f"ALTER AGENT GN_DW.SERVING.{a} ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/{a}' COMMENT = 'O206-D 개발(건) 소수4자리 · 신규기존구분'")
    # [5] 검증
    c.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{a}')
    rows = c.fetchall(); cols = [d[0] for d in c.description]
    d = [r for r in rows if r[cols.index('is_default')] in (True, 'true')][0]
    spec = d[cols.index('agent_spec')] or ''
    print(f'[5] {a} 직전 default={before} → 신 default={d[cols.index("name")]}',
          'O206C=' + str('[O206-C 수치 근거' in spec), 'O206_orch=' + str('[O206 · O201-B 개정]' in spec),
          'tools=%d' % spec.count('tool_spec'))
