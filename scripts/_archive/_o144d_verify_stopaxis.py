#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서16 §4-1 「중단 축 배선 완료」 주장의 실효를 STOP 행의 캠페인·사업 축 채움률로 판정한다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("STOP 행의 캠페인축 · 사업축 채움률", """
        SELECT EVENT_TYPE,
               COUNT(*) AS ROWS_N,
               COUNT(CASE WHEN CAMPAIGN_SK IS NOT NULL AND CAMPAIGN_SK <> 0 THEN 1 END) AS CAMP_OK,
               COUNT(CASE WHEN CAMPAIGN_SK = 0 THEN 1 END) AS CAMP_ZERO,
               COUNT(CASE WHEN SPONSORSHIP_SK IS NOT NULL AND SPONSORSHIP_SK <> 0 THEN 1 END) AS SPNSR_OK,
               COUNT(CASE WHEN SPONSORSHIP_SK = 0 THEN 1 END) AS SPNSR_ZERO
        FROM GN_DW.GOLD.FACT_MEMBER_EVENT
        GROUP BY 1 ORDER BY 2 DESC
    """),
    ("FACT_MEMBER_EVENT.SPONSORSHIP_SK 컬럼 COMMENT (센티넬 사유 발행 여부)", """
        SELECT COLUMN_NAME, COMMENT FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='FACT_MEMBER_EVENT'
          AND COLUMN_NAME IN ('SPONSORSHIP_SK','CAMPAIGN_SK')
    """),
    ("획득축 정본 DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_SK 채움률", """
        SELECT COUNT(*) AS ROWS_N,
               COUNT(CASE WHEN ACQ_CAMPAIGN_SK IS NOT NULL AND ACQ_CAMPAIGN_SK <> 0 THEN 1 END) AS ACQ_OK,
               COUNT(CASE WHEN ACQ_SPONSORSHIP_SK IS NOT NULL AND ACQ_SPONSORSHIP_SK <> 0 THEN 1 END) AS ACQ_SPNSR_OK
        FROM GN_DW.GOLD.DIM_MEMBER_ACQUISITION
    """),
]


def main():
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")
    for title, sql in Q:
        print("\n=== %s ===" % title)
        rows = cur.execute(sql).fetchall()
        print("  행수 = %d" % len(rows))
        for r in rows:
            print("  " + " | ".join("" if v is None else str(v) for v in r))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
