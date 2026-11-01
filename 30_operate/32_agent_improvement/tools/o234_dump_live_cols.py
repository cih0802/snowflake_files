# O234 — 라이브 SILVER·GOLD 컬럼을 o163_ddl_live_drift.py 입력 TSV 로 덤프
# Co-authored with CoCo
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from o217_agent_io import session  # noqa: E402

rows = session().sql(
    "select TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME from GN_DW.INFORMATION_SCHEMA.COLUMNS "
    "where TABLE_SCHEMA in ('SILVER','GOLD') "
    "and TABLE_NAME in (select TABLE_NAME from GN_DW.INFORMATION_SCHEMA.TABLES "
    "where TABLE_SCHEMA = COLUMNS.TABLE_SCHEMA and TABLE_TYPE = 'BASE TABLE')"
).collect()
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/live_cols.tsv"
with open(out, "w", encoding="utf-8") as f:
    for r in rows:
        f.write("%s\t%s\t%s\n" % (r[0], r[1], r[2]))
print(out, len(rows))
