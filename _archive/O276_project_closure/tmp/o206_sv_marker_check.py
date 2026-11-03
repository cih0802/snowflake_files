# O206-C — 라이브 SV 전수: AI_SQL_GENERATION 에 지정 마커가 있는가
# 사용: python3 tmp/o206_sv_marker_check.py "<마커>" ["<마커2>" ...]
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

marks = sys.argv[1:]
c = conn().cursor(); c.execute('USE ROLE GN_DW_ADMIN')
c.execute('SHOW SEMANTIC VIEWS IN DATABASE GN_DW'); names = [r[1] for r in c.fetchall()]
ok = {m: 0 for m in marks}
for n in names:
    c.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.SERVING.{n}')
    v = [r[4] for r in c.fetchall() if r[3] == 'AI_SQL_GENERATION']
    for m in marks:
        if v and m in v[0]:
            ok[m] += 1
        else:
            print('MISS', m, n)
print('SV', len(names), ok)
