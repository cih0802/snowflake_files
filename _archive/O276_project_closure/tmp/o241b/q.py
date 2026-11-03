import sys
sys.path.insert(0, sys.path[0] + '/../../scripts')
from sfconn import conn
c = conn().cursor(); c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
for q in sys.stdin.read().split(';;'):
    if q.strip():
        c.execute(q); print([d[0] for d in c.description]); [print(r) for r in c.fetchmany(40)]; print('--')
