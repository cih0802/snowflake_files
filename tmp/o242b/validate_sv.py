# O242-B — SV DDL 임시 이름 검증(CREATE SEMANTIC VIEW 문만 · <이름>_O242TMP 로 생성 후 DROP) · Co-authored with CoCo
import io, os, re, sys
B = os.path.dirname(os.path.abspath(__file__)) + '/../../'
sys.path.insert(0, B + 'scripts')
from sfconn import conn
from snowflake.connector.util_text import split_statements
cn = conn(); c = cn.cursor()
for s in ('USE ROLE GN_DW_ADMIN', 'USE WAREHOUSE GN_DW_DEV_WH', 'USE SCHEMA GN_DW.SERVING'):
    c.execute(s)
P = re.compile(r'CREATE OR (?:ALTER|REPLACE) SEMANTIC VIEW\s+(GN_DW\.SERVING\.\w+)', re.I)
ok = bad = 0
for f in sys.argv[1:]:
    for st, _ in split_statements(io.open(f, encoding='utf-8'), remove_comments=True):
        m = P.search(st)
        if not m:
            continue
        tmp = m.group(1) + '_O242TMP'
        sql = st[:m.start()] + 'CREATE OR REPLACE SEMANTIC VIEW ' + tmp + st[m.end():]
        try:
            c.execute(sql); ok += 1; print('OK', os.path.basename(f), m.group(1).split('.')[-1], flush=True)
        except Exception as e:
            bad += 1; print('🔴', os.path.basename(f), m.group(1).split('.')[-1], str(e)[:300], flush=True)
        finally:
            c.execute(f'DROP SEMANTIC VIEW IF EXISTS {tmp}')
print('PASS', ok, 'FAIL', bad)
sys.exit(1 if bad else 0)
