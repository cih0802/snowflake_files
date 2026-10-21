#!/usr/bin/env python3
"""O255 · SV DDL 파일 1개를 문장 단위로 실행한다(파일 단독 실행 실증 · CREATE OR ALTER).
사용법: python3 tmp/o255/run_sv_file.py 05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql
"""
import io
import os
import sys
from pathlib import Path

import snowflake.connector
from snowflake.connector.util_text import split_statements

f = Path("/workspace") / sys.argv[1]
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                  authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH")
cur = con.cursor()
stmts = [s for s, _ in split_statements(io.StringIO(f.read_text(encoding="utf-8")), remove_comments=True) if s.strip()]
ok = bad = 0
for s in stmts:
    try:
        cur.execute(s)
        if s.lstrip().upper().startswith(("SELECT", "SHOW")):
            print("   결과", s.split()[0], cur.fetchall()[:5])
        ok += 1
    except Exception as e:
        bad += 1
        print("🔴", s[:80].replace("\n", " "), "→", str(e)[:300])
print(("🟢" if bad == 0 else "🔴"), f.name, f"{ok}/{len(stmts)}")
sys.exit(1 if bad else 0)
