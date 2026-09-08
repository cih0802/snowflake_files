#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서16 §3-3 이 인용한 영구NULL COMMENT 대상 2개 컬럼의 실재와 COMMENT 내용을 라이브에서 확인한다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("16 §3-3 인용 컬럼 실재", """
        SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE (TABLE_NAME='CRM_BIZ_TARGET' AND COLUMN_NAME ILIKE '%CAMPAIGN%')
           OR (TABLE_NAME='FACT_BUDGET_DEPARTMENT' AND COLUMN_NAME ILIKE '%DEPT%')
        ORDER BY 1,2,3
    """),
    ("CRM_BIZ_TARGET 전 컬럼", """
        SELECT TABLE_SCHEMA, COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME='CRM_BIZ_TARGET' ORDER BY ORDINAL_POSITION
    """),
    ("K-2 · 문서16 가 주장한 SV_EVENT_PARTICIPATION 인원·건수 이원화 metric", """
        SHOW SEMANTIC METRICS IN SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
    """),
]


def main():
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")
    for title, sql in Q:
        print("\n=== %s ===" % title)
        try:
            rows = cur.execute(sql).fetchall()
        except Exception as exc:
            print("  🟠 실행 실패 — %s: %s" % (type(exc).__name__, exc))
            continue
        print("  행수 = %d" % len(rows))
        for r in rows:
            print("  " + " | ".join("" if v is None else str(v) for v in r))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
