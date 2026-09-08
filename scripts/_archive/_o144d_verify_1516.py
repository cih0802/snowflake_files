#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서15/16/17 파생 무결성 검증용 일회성 실측 — K-2 인원·횟수 이원화, H-3 성별축, ㊶ COMMENT, ⑭ FME 센티넬을 라이브에서 센다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("K-2 · FACT_EVENT_PARTICIPATION 인원·횟수 계열 컬럼", """
        SELECT COLUMN_NAME, COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='FACT_EVENT_PARTICIPATION'
          AND (COLUMN_NAME ILIKE '%CNT%' OR COLUMN_NAME ILIKE '%MEMBER%'
               OR COLUMN_NAME ILIKE '%PARTICIP%')
        ORDER BY 1
    """),
    ("H-3 · DIM_MEMBER 성별 계열 컬럼", """
        SELECT COLUMN_NAME, COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_MEMBER'
          AND (COLUMN_NAME ILIKE '%GENDER%' OR COLUMN_NAME ILIKE '%SEX%')
        ORDER BY 1
    """),
    ("㊶ · 영구 NULL 사유 COMMENT 잔존 여부", """
        SELECT TABLE_SCHEMA || '.' || TABLE_NAME || '.' || COLUMN_NAME AS OBJ, COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA IN ('GOLD','SILVER')
          AND (COMMENT ILIKE '%원천 미수집%' OR COMMENT ILIKE '%영구 NULL%'
               OR COMMENT ILIKE '%원천 부재%')
        ORDER BY 1
    """),
    ("⑭ · FACT_MEMBER_EVENT STOP 후원사업 센티넬 분포", """
        SELECT EVENT_TYPE,
               COUNT(*) AS ROWS_N,
               COUNT(CASE WHEN SPONSORSHIP_SK = 0 THEN 1 END) AS SK_ZERO,
               COUNT(CASE WHEN SPONSORSHIP_SK <> 0 THEN 1 END) AS SK_NONZERO
        FROM GN_DW.GOLD.FACT_MEMBER_EVENT
        GROUP BY 1 ORDER BY 2 DESC
    """),
    ("L-2 · 2-Track 획득/중단 축 컬럼 실재", """
        SELECT TABLE_NAME, COLUMN_NAME
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='GOLD'
          AND (COLUMN_NAME ILIKE 'ACQUISITION%SK' OR COLUMN_NAME ILIKE 'STOP%SK')
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
        if not rows:
            print("  (0행)")
        for r in rows:
            print("  " + " | ".join("" if v is None else str(v) for v in r))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
