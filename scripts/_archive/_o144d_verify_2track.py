#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서16 §4-1 의 「2-Track 축 분리 배선 완료」 주장을 라이브 컬럼 실재로 반증·입증하기 위해 명명 변형을 넓혀 센다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("가 · FACT_MEMBER_EVENT 전 컬럼", """
        SELECT COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='FACT_MEMBER_EVENT' ORDER BY ORDINAL_POSITION
    """),
    ("나 · FACT_MEMBER_MONTHLY 캠페인·사업 계열 컬럼", """
        SELECT COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='FACT_MEMBER_MONTHLY'
          AND (COLUMN_NAME ILIKE '%CAMPAIGN%' OR COLUMN_NAME ILIKE '%SPONSOR%'
               OR COLUMN_NAME ILIKE '%ACQ%' OR COLUMN_NAME ILIKE '%STOP%')
        ORDER BY 1
    """),
    ("다 · GOLD 전체에서 ACQ/STOP 을 이름에 가진 컬럼 전건", """
        SELECT TABLE_NAME, COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD'
          AND (COLUMN_NAME ILIKE '%ACQ%' OR COLUMN_NAME ILIKE '%STOP%'
               OR COLUMN_NAME ILIKE '%DSCNTC%' OR COLUMN_NAME ILIKE '%DISCONT%')
        ORDER BY 1, 2
    """),
    ("라 · DIM_MEMBER_ACQUISITION 실재 여부", """
        SELECT TABLE_NAME, TABLE_TYPE, ROW_COUNT FROM GN_DW.INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME ILIKE '%ACQUISITION%'
    """),
    ("마 · D+5 반응기간이 코멘트로 발행된 GOLD 컬럼", """
        SELECT TABLE_NAME, COLUMN_NAME FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD'
          AND (COMMENT ILIKE '%D+5%' OR COLUMN_NAME ILIKE '%D5%'
               OR COMMENT ILIKE '%반응 기간%' OR COMMENT ILIKE '%반응기간%')
        ORDER BY 1, 2
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
