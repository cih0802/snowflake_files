import sys
sys.path.insert(0, "/workspace/scripts")
from sfconn import conn
from deploy_sv import split_sql, strip_lead

P = "/workspace/05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql"
KEEP = ("USE", "CREATE", "COPY", "TRUNCATE", "GRANT")
txt = open(P, encoding="utf-8").read()
cn = conn(); cur = cn.cursor()
n = 0
for s in split_sql(txt):
    body = strip_lead(s)
    head = body.split(None, 1)[0].upper() if body else ""
    if head in KEEP:
        cur.execute(body)
        n += 1
        print("OK", head, body.split("\n", 1)[0][:90])
print("executed", n)
