# GN_DW.GOLD DDL 전체 실행 (24 CREATE TABLE + 35 FK ALTER + 검증 쿼리)
# Co-authored with CoCo
import os, re, sys
import snowflake.connector

# Session token
token_path = os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")
token = open(token_path).read().strip()

conn = snowflake.connector.connect(
    account   = os.environ.get("SNOWFLAKE_ACCOUNT", "qi50743"),
    host      = os.environ.get("SNOWFLAKE_HOST", "qi50743.snowflakecomputing.com"),
    authenticator = "oauth",
    token     = token,
    warehouse = "COMPUTE_WH",
    database  = "GN_DW",
    schema    = "GOLD",
)
cur = conn.cursor()

ddl = open("/workspace/03_top-down_gold/06_DDL.sql", encoding="utf-8").read()

# Split into statements by semicolon (skip USE, SHOW, pure-comment blocks)
stmts = []
for raw in ddl.split(";"):
    s = raw.strip()
    # skip empty, comment-only, USE, SHOW
    lines = [l for l in s.split("\n") if l.strip() and not l.strip().startswith("--")]
    sql = "\n".join(lines).strip()
    if not sql or sql.upper().startswith("USE ") or sql.upper().startswith("SHOW ") or sql.startswith("/*"):
        continue
    stmts.append(sql)

print(f"Executing {len(stmts)} statements...")
errors = 0
for i, stmt in enumerate(stmts, 1):
    first_line = stmt.split("\n")[0][:80]
    try:
        cur.execute(stmt)
        status = cur.fetchone()
        print(f"  [{i:02d}] OK  | {first_line}")
    except Exception as e:
        errors += 1
        print(f"  [{i:02d}] ERR | {first_line}")
        print(f"        ↳ {e}")

cur.close()
conn.close()
print(f"\n{'='*60}")
print(f"Done: {len(stmts)-errors} OK, {errors} errors")
