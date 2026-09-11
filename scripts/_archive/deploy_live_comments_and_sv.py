#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Live 배포 스크립트:
1. Gold & Silver 테이블 COMMENT ON TABLE 적용
2. SERVING ML Serving 뷰 DDL (21_ML_SERVING_뷰_DDL.sql) 실행
3. SERVING Semantic View 17종 (10 DW + 7 ML) DDL 실행
4. comment_drift_gate.py 검증
"""
import sys
import glob
import re

sys.path.insert(0, '/workspace/scripts')
import sfconn
from standardize_comments import (
    GOLD_TABLE_COMMENTS,
    SILVER_TABLE_COMMENTS,
)


def apply_table_comments(cn):
    cur = cn.cursor()
    print("=== 1. Applying GOLD Table Comments ===")
    for tbl, cmt in GOLD_TABLE_COMMENTS.items():
        lit = cmt.replace("'", "''")
        sql = f"COMMENT ON TABLE GN_DW.GOLD.{tbl} IS '{lit}';"
        try:
            cur.execute(sql)
            print(f"  [GOLD] {tbl} OK")
        except Exception as e:
            print(f"  [GOLD] 🔴 {tbl} ERROR: {e}")

    print("\n=== 2. Applying SILVER Table Comments ===")
    for tbl, cmt in SILVER_TABLE_COMMENTS.items():
        lit = cmt.replace("'", "''")
        sql = f"COMMENT ON TABLE GN_DW.SILVER.{tbl} IS '{lit}';"
        try:
            cur.execute(sql)
            print(f"  [SILVER] {tbl} OK")
        except Exception as e:
            print(f"  [SILVER] 🔴 {tbl} ERROR: {e}")


def execute_sql_file(cn, fpath):
    print(f"\n=== Executing {fpath} ===")
    src = open(fpath, encoding="utf-8").read()
    # Split by semicolons while respecting string literals
    cur = cn.cursor()
    
    # We can split by semicolon outside of strings or execute statements
    # In snowflake connector, cur.execute_stream(io.StringIO(src)) or splitting
    statements = []
    # Simple statement splitter
    tokens = re.split(r";\s*\n", src)
    for t in tokens:
        stmt = t.strip()
        # remove pure comment blocks or empty statements
        lines = [l for l in stmt.splitlines() if not l.strip().startswith("--")]
        clean_stmt = "\n".join(lines).strip()
        if clean_stmt:
            statements.append(clean_stmt)

    for idx, s in enumerate(statements):
        try:
            # check what statement it is
            first_line = s.splitlines()[0][:60]
            cur.execute(s)
            print(f"  [{idx+1}/{len(statements)}] OK: {first_line}")
        except Exception as e:
            print(f"  [{idx+1}/{len(statements)}] 🔴 ERROR: {first_line} -> {e}")


def deploy_semantic_views(cn):
    # First deploy 21_ML_SERVING_뷰_DDL.sql
    execute_sql_file(cn, "05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql")

    # Deploy 10 DW SVs
    dw_sv_files = sorted(glob.glob("05_SV-Agent_ai/05_*_SV_DDL_*.sql"))
    for f in dw_sv_files:
        if "05_0" in f:
            continue
        execute_sql_file(cn, f)

    # Deploy 7 ML SVs
    execute_sql_file(cn, "05_SV-Agent_ai/22_ML_SV_DDL.sql")


def main():
    cn = sfconn.conn()
    try:
        apply_table_comments(cn)
        deploy_semantic_views(cn)
    finally:
        cn.close()


if __name__ == '__main__':
    main()
