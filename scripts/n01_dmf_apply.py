#!/usr/bin/env python3
"""O247 · N01 DMF 적용 — N01_DMF_적용완료.sql 의 [1]~[4] 를 GN_DW_ADMIN 으로 문장 단위 실행.
결과(문장 · 상태 · 오류)를 tmp/o247/n01_apply.csv 에 남긴다. 실패해도 다음 문장으로 계속(멱등 ALTER … ADD 는 재실행 시 '이미 존재' 오류).
O249-D: 기본 = dry-run(문장 목록만 출력 · 접속 없음). 실제 실행은 `--apply` 필수.
"""
import argparse
import csv
import os
import re
import sys
from pathlib import Path

SQL = Path("/workspace/85_실제 인수인계 문서/20_정식산출물/N01_DMF_적용완료.sql")
ap = argparse.ArgumentParser()
ap.add_argument("out", nargs="?", default="/workspace/tmp/n01_apply.csv")
ap.add_argument("--apply", action="store_true", help="실제 실행(미지정 시 dry-run)")
a = ap.parse_args()
OUT = Path(a.out)

text = SQL.read_text(encoding="utf-8")
body = text.split("USE ROLE GN_DW_ADMIN;", 1)[1].split("-- [5]", 1)[0]
stmts = [s.strip() for s in re.split(r";\s*\n", body)
         if s.strip() and not all(l.strip().startswith("--") or not l.strip() for l in s.splitlines())]
stmts = ["\n".join(l for l in s.splitlines() if not l.strip().startswith("--")).strip() for s in stmts]

if not a.apply:
    for i, s in enumerate(stmts, 1):
        print(f"[PLAN {i}] {s[:160]}")
    print(f"dry-run · 문장 {len(stmts)} · 실행하려면 --apply")
    sys.exit(0)

import snowflake.connector

tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                  authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH",
                                  database="GN_DW")
cur = con.cursor()
rows, ok, ng = [], 0, 0
for i, s in enumerate(stmts, 1):
    try:
        cur.execute(s)
        rows.append([i, "OK", "", s[:160]])
        ok += 1
    except Exception as e:  # 실패는 기록하고 계속
        rows.append([i, "ERROR", str(e).replace("\n", " ")[:240], s[:160]])
        ng += 1
with OUT.open("w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f)
    w.writerow(["N", "STATUS", "ERROR", "STMT"])
    w.writerows(rows)
print(f"문장 {len(stmts)} · OK {ok} · ERROR {ng} → {OUT}")
sys.exit(0 if ng == 0 else 1)
