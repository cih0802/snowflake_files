#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# N-9(캠페인명 시점 동결) 보강 근거 — GOLD 동결값과 현재 마스터명이 실제로 갈라졌는지 라이브에서 센다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("N9-a · 획득 시점 동결명 ↔ 현재 캠페인 마스터명 불일치 규모", """
        SELECT COUNT(*) AS ROWS_N,
               COUNT(CASE WHEN a.ACQ_CAMPAIGN_NAME <> c.CAMPAIGN_NAME THEN 1 END) AS DIFF_ROWS,
               COUNT(DISTINCT CASE WHEN a.ACQ_CAMPAIGN_NAME <> c.CAMPAIGN_NAME
                                   THEN a.ACQ_CAMPAIGN_SK END) AS DIFF_CAMPAIGNS
        FROM GN_DW.GOLD.DIM_MEMBER_ACQUISITION a
        JOIN GN_DW.GOLD.DIM_CAMPAIGN c ON c.CAMPAIGN_SK = a.ACQ_CAMPAIGN_SK
    """),
    ("N9-b · DIM_CAMPAIGN 에 이름 컬럼이 무엇인지", """
        SELECT COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_CAMPAIGN'
          AND COLUMN_NAME ILIKE '%NAME%' ORDER BY 1
    """),
    ("N9-c · 캠페인 마스터 최종변경일 분포 (개칭 발생 시기)", """
        SELECT LEFT(TO_CHAR(last_updt_dt,'YYYYMMDD'),4) AS YR,
               COUNT(*) AS CAMPAIGNS
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
        GROUP BY 1 ORDER BY 1
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
            print("  🔴 실패 — %s: %s" % (type(exc).__name__, str(exc).split('\n')[0]))
            continue
        print("  " + " | ".join(d[0] for d in cur.description))
        for r in rows[:30]:
            print("  " + " | ".join("" if v is None else str(v) for v in r))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
