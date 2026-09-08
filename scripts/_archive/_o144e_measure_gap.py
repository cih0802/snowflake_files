#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 1차 측정에서 실패·미측정으로 남은 축(회비월 실제 보정 충돌·행사 마스터 연도범위·캠페인행사 고아)을 보완 측정한다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

Q = [
    ("A-b · 올바른 보정식(연4+월2)으로 복원할 때 기존 6자리와 충돌하는지", """
        WITH five AS (
            SELECT DISTINCT mbrfee_mt AS raw5,
                   LEFT(mbrfee_mt,4) || LPAD(RIGHT(mbrfee_mt,1),2,'0') AS ym_fix
            FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
            WHERE LENGTH(mbrfee_mt) = 5)
        SELECT f.raw5, f.ym_fix,
               (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT a
                 WHERE a.mbrfee_mt = f.ym_fix) AS EXISTING_ROWS,
               (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT a
                 WHERE a.mbrfee_mt = f.raw5)   AS FIVE_DIGIT_ROWS
        FROM five f ORDER BY 1
    """),
    ("A-c · 단순 LPAD 결과가 의미를 갖는지 (020251 형태)", """
        SELECT DISTINCT mbrfee_mt AS raw5,
               LPAD(mbrfee_mt, 6, '0') AS naive_lpad,
               LEFT(mbrfee_mt,4) || LPAD(RIGHT(mbrfee_mt,1),2,'0') AS ym_fix
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
        WHERE LENGTH(mbrfee_mt) = 5 ORDER BY 1
    """),
    ("EV-a · TM_MS_EVENT 컬럼 목록 (연도범위 측정용 컬럼 확인)", """
        SELECT COLUMN_NAME, DATA_TYPE FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA='BRONZE_CRM' AND TABLE_NAME='TM_MS_EVENT'
        ORDER BY ORDINAL_POSITION
    """),
    ("CRMN-a · 캠페인행사 고아 재확인 + 마스터 규모", """
        SELECT (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TM_MS_CRMN)          AS MASTER_ROWS,
               (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT)  AS PART_ROWS,
               (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT p
                 WHERE NOT EXISTS (SELECT 1 FROM GN_DW.BRONZE_CRM.TM_MS_CRMN c
                                    WHERE c.crmn_cd = p.crmn_cd))          AS ORPHAN_ROWS
    """),
    ("EV-b · 일반행사 마스터 규모 대비 참여가 참조하는 행사코드 종수", """
        SELECT (SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.TM_MS_EVENT) AS MASTER_ROWS,
               COUNT(DISTINCT p.event_cd) AS REFERENCED_KINDS,
               COUNT(DISTINCT CASE WHEN e.event_cd IS NULL THEN p.event_cd END) AS ORPHAN_KINDS
        FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL p
        LEFT JOIN GN_DW.BRONZE_CRM.TM_MS_EVENT e ON e.event_cd = p.event_cd
    """),
    ("M5-d · 미등재 실패코드 5종의 건수 분해", """
        SELECT d.trnsms_failr_cd_id AS CODE, COUNT(*) AS ROWS_N
        FROM GN_DW.BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS d
        WHERE d.trnsms_failr_cd_id IS NOT NULL
          AND NOT EXISTS (
                SELECT 1 FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD c
                WHERE c.cd_id IN ('MS056','MS057','MS058','MS059')
                  AND c.dtl_cd_id = d.trnsms_failr_cd_id)
        GROUP BY 1 ORDER BY 2 DESC
    """),
    ("F2-b · 약어코드별 사업수 (그룹 종수 확정)", """
        SELECT spnsr_bsns_abrv_cd AS ABRV, COUNT(*) AS BSNS_N
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
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
        for r in rows[:40]:
            print("  " + " | ".join("" if v is None else str(v) for v in r))
        if len(rows) > 40:
            print("  ... 총 %d행" % len(rows))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
