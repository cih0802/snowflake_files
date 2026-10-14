#!/usr/bin/env python3
"""O229 D8 — Agent 객체 COMMENT 에 소관 SV 종수 선언 추가(라이브 + 09_1 파일 · 2곳 동일 문자열).
실측 = cortex_project/agents/*/agent_spec.yaml 의 semantic_view 고유 수 = MEMBER 24 · EXECUTIVE 14 · MARKETING 25.
사용: python3 tmp/o229/fix_agent_comment.py [dry]
Co-authored with CoCo
"""
import io, sys, hashlib
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

N = {'AGENT_MEMBER': 24, 'AGENT_EXECUTIVE': 14, 'AGENT_MARKETING': 25}
F = '/workspace/05_SV-Agent_ai/09_1_AGENT_생성.sql'
dry = 'dry' in sys.argv
cur = conn().cursor()
for s in ('USE ROLE GN_DW_ADMIN', 'USE WAREHOUSE GN_DW_ETL_WH'):
    cur.execute(s)
h = [hashlib.sha256(open(F, 'rb').read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], 'hash unstable'
t = io.open(F, encoding='utf-8').read()
rows = cur.execute('SHOW AGENTS IN SCHEMA GN_DW.SERVING').fetchall()
cols = [c[0] for c in cur.description]
for r in rows:
    d = dict(zip(cols, r))
    name, cmt = d['name'], d['comment'] or ''
    if name not in N:
        continue
    tag = f' · 소관 SV {N[name]}종(+ 비즈니스정의 Search)'
    if '소관 SV' in cmt:
        print('skip', name)
        continue
    new = cmt + tag
    k = t.count("'" + cmt.replace("'", "''") + "'")
    print(name, 'file hits', k, 'len', len(new))
    if dry:
        continue
    t = t.replace("'" + cmt.replace("'", "''") + "'", "'" + new.replace("'", "''") + "'")
    cur.execute(f"ALTER AGENT GN_DW.SERVING.{name} SET COMMENT = %s", (new,))
if not dry:
    io.open(F, 'w', encoding='utf-8').write(t)
    for r in cur.execute('SHOW AGENTS IN SCHEMA GN_DW.SERVING').fetchall():
        d = dict(zip(cols, r))
        print('live', d['name'], '소관 SV' in (d['comment'] or ''))
