#!/usr/bin/env python3
"""O250 · 36_ DDL 문장 파일(tmp/o250/stmt*.sql + GRANT)을 GN_DW_ADMIN 으로 순서 실행하고 결과를 출력한다."""
import os
import re
import sys
from pathlib import Path

import snowflake.connector

SRC = Path("/workspace/05_SV-Agent_ai/36_O250_ML예측_7축확장.sql")
files = [Path(f"/workspace/tmp/o250/stmt{i}.sql") for i in (1, 2, 3, 4)]
only = sys.argv[1:]  # 예: 1 2 → stmt1·stmt2 만
stmts = [(f.name, f.read_text(encoding="utf-8")) for f in files if not only or f.stem[-1] in only]
if not only or "g" in only:
    grants = re.findall(r"^GRANT [^\n]+;", SRC.read_text(encoding="utf-8"), re.M)
    stmts += [("grant", g) for g in grants]

tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                  authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH",
                                  database="GN_DW", schema="SERVING")
cur = con.cursor()
ng = 0
for name, s in stmts:
    try:
        cur.execute(s)
        print("OK   ", name, s[:70].replace("\n", " "))
    except Exception as e:
        ng += 1
        print("ERROR", name, str(e).replace("\n", " ")[:300])
sys.exit(1 if ng else 0)
