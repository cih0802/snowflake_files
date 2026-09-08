#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서16 §3-3 의 FACT_BUDGET_DEPARTMENT.DEPT_CD 실재와 SV_EVENT_PARTICIPATION 인원·건수 metric 을 정확한 구문으로 확인한다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn


def main():
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")

    print("=== 예산 부서 테이블 실재 ===")
    rows = cur.execute("""
        SELECT TABLE_SCHEMA, TABLE_NAME FROM GN_DW.INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME ILIKE '%BUDGET%' ORDER BY 1,2
    """).fetchall()
    print("  행수 = %d" % len(rows))
    for r in rows:
        print("  " + " | ".join(str(v) for v in r))

    print("\n=== 예산 테이블의 부서 계열 컬럼 ===")
    rows = cur.execute("""
        SELECT TABLE_NAME, COLUMN_NAME, COMMENT FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME ILIKE '%BUDGET%'
          AND (COLUMN_NAME ILIKE '%DEPT%' OR COLUMN_NAME ILIKE '%ORG%')
        ORDER BY 1,2
    """).fetchall()
    print("  행수 = %d" % len(rows))
    for r in rows:
        print("  " + " | ".join("" if v is None else str(v) for v in r))

    print("\n=== SV_EVENT_PARTICIPATION 정의 (인원·건수 metric 확인) ===")
    rows = cur.execute("DESC SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION").fetchall()
    for r in rows:
        line = " | ".join("" if v is None else str(v) for v in r)
        if 'METRIC' in line.upper() or 'metric' in line:
            print("  " + line[:300])
    print("\nrc_ok")


if __name__ == '__main__':
    main()
