import io, sys, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
from snowflake.connector.util_text import split_statements
p = sys.argv[1]
cn = conn()
cur = cn.cursor()
ok = 0
for s, _ in split_statements(io.StringIO(io.open(p, encoding='utf-8').read()), remove_comments=True):
    s = s.strip()
    if not s:
        continue
    head = ' '.join(s.split())[:90]
    try:
        cur.execute(s)
        ok += 1
        print('OK  ', head, cur.sfqid)
    except Exception as e:
        print('FAIL', head, str(e)[:300])
        sys.exit(1)
print('done', ok)
