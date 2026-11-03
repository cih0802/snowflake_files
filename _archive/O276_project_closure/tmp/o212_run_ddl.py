# O212 — SQL 파일 1개를 GN_DW_ADMIN 으로 실행(USE ROLE 은 파일 첫 문장에 있다) · 문장별 결과 요약
# 사용: python3 tmp/o212_run_ddl.py <파일>
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
p = sys.argv[1]
sql = open(p, encoding='utf-8').read()
c = conn()
n = 0
for cur in c.execute_string(sql, remove_comments=False):
    n += 1
    r = cur.fetchone()
    print(n, str(r)[:120] if r else '-')
print('OK statements =', n)
