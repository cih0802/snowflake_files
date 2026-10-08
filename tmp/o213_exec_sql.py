"""O213 — SQL 파일 1개(단일 문장)를 지정 역할로 실행한다. 사용: python3 o213_exec_sql.py <file.sql> [ROLE] [WH]"""
import io, os, sys
import snowflake.connector

path = sys.argv[1]
role = sys.argv[2] if len(sys.argv) > 2 else "GN_DW_ADMIN"
wh = sys.argv[3] if len(sys.argv) > 3 else "GN_DW_DEV_WH"
token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"], host=os.environ.get("SNOWFLAKE_HOST"),
    authenticator="oauth", token=token, role=role, warehouse=wh, database="GN_DW", schema="SERVING")
cur = con.cursor()
stmt = io.open(path, encoding="utf-8").read().strip().rstrip(";")
cur.execute(stmt)
print("OK", cur.fetchone(), "role=", cur.execute("select current_role()").fetchone()[0])
con.close()
