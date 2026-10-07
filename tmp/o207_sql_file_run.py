#!/usr/bin/env python3
# O207 W2 — SQL 정본 파일 전체 실행(USE ROLE 포함 · 문장 분리는 커넥터 execute_string) · 사용: <sql 파일>
# Co-authored with CoCo
import io, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn
path = sys.argv[1]
cn = conn()
n = 0
for cur in cn.execute_string(io.open(path, encoding='utf-8').read(), remove_comments=True):
    n += 1
    print(n, (cur.query or '').strip().splitlines()[0][:90], '→', cur.rowcount)
cn.close()
print('OK statements =', n)
