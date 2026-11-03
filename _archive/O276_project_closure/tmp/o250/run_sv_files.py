#!/usr/bin/env python3
"""O250-E · 05_27~05_30 단독 파일을 문장 단위로 실행해 파일 완결성을 실증한다(CREATE OR ALTER · 같은 정의 = 무해)."""
import os
import io
import sys
from pathlib import Path

import snowflake.connector
from snowflake.connector.util_text import split_statements

D = Path("/workspace/05_SV-Agent_ai")
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                  authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH")
cur = con.cursor()
bad = 0
for f in sorted(D.glob("05_2[7-9]_SV_DDL_*.sql")) + sorted(D.glob("05_30_SV_DDL_*.sql")):
    stmts = [s for s, _ in split_statements(io.StringIO(f.read_text(encoding="utf-8")), remove_comments=True) if s.strip()]
    ok = 0
    for s in stmts:
        try:
            cur.execute(s)
            if s.lstrip().upper().startswith("SELECT"):
                rows = cur.fetchall()
                print("   스모크", f.name, rows[:3])
            ok += 1
        except Exception as e:
            bad += 1
            print("🔴", f.name, str(e)[:200])
    print(("🟢" if ok == len(stmts) else "🔴"), f.name, f"{ok}/{len(stmts)}")
sys.exit(1 if bad else 0)
