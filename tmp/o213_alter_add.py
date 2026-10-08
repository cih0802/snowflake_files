"""O213-D — 정본 DDL 에 추가된 컬럼을 물리 테이블에 ALTER ADD(존재하는 컬럼은 건너뜀 · COMMENT 포함).
사용: python3 o213_alter_add.py <ddl.sql> <SCHEMA.TABLE> [--apply]"""
import io, os, re, sys
import snowflake.connector

ddl, fq = sys.argv[1], sys.argv[2]
APPLY = "--apply" in sys.argv
sch, tbl = fq.split(".")
t = io.open(ddl, encoding="utf-8").read()
m = re.search(r"CREATE OR REPLACE TABLE GN_DW\." + sch + r"\." + tbl + r" \((.*?)\n\) COMMENT", t, re.S)
cols = []
for line in m.group(1).split("\n"):
    s = line.strip().rstrip(",")
    mm = re.match(r"^([A-Z0-9_]+)\s+([A-Z_]+(?:\([0-9, ]+\))?)\s+(?:NOT NULL\s+)?(?:PRIMARY KEY\s+)?COMMENT\s+'(.*)'$", s)
    if mm:
        cols.append(mm.groups())
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(account=os.environ["SNOWFLAKE_ACCOUNT"], host=os.environ.get("SNOWFLAKE_HOST"),
                                  authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH", database="GN_DW")
cur = con.cursor()
have = {r[0] for r in cur.execute(f"select column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='{sch}' and table_name='{tbl}'").fetchall()}
add = [c for c in cols if c[0] not in have]
print(f"DDL cols={len(cols)} physical={len(have)} to_add={len(add)}")
for name, typ, cmt in add:
    stmt = f"ALTER TABLE GN_DW.{sch}.{tbl} ADD COLUMN {name} {typ} COMMENT '{cmt}'"
    print(("APPLY " if APPLY else "DRY ") + name, typ)
    if APPLY:
        cur.execute(stmt)
if APPLY:
    after = {r[0] for r in cur.execute(f"select column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='{sch}' and table_name='{tbl}'").fetchall()}
    miss = [c[0] for c in cols if c[0] not in after]
    print("after physical =", len(after), "DDL 대비 누락 =", miss)
con.close()
