#!/usr/bin/env python3
"""env_capture 음성 테스트 (R3-2) — 쓰기 문장이 섞이면 **접속 전에** rc=1, 정상 파싱은 블록·문장 수 일치."""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import env_capture as ec  # noqa: E402

fails = 0


def check(name, cond):
    global fails
    print(('🟢 ' if cond else '🔴 ') + name)
    fails += 0 if cond else 1


txt = '-- Q01 a\nSELECT 1;\nSHOW ROLES;\n-- Q02 b\nSELECT\n  2\nFROM X;\n'
b = ec.parse_blocks(txt)
check('파싱 = 블록 2 · 문장 2+1', [len(x[2]) for x in b] == [2, 1])

for bad in ('GRANT ROLE R TO USER U;', 'CREATE TABLE T (A INT);', 'ALTER USER U SET X = 0;'):
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write('-- Q01 x\nSELECT 1;\n' + bad + '\n')
    env = dict(os.environ, SNOWFLAKE_ACCOUNT='__no_connect__', SNOWFLAKE_TOKEN_FILE_PATH='/nonexistent')
    p = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'env_capture.py'),
                        '--id', 'T', f.name], capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)
    check('거부 rc=1 · 미접속: ' + bad.split()[0], p.returncode == 1 and '거부' in p.stdout)
    os.unlink(f.name)

cells, cut = ec.fit_row(['x' * 3000, 'a\nb'])
check('행 절단 ≤1900 · 개행 치환', sum(len(c) + 3 for c in cells) <= 1900 and cut >= 1 and '⏎' in cells[1])

sys.exit(1 if fails else 0)
