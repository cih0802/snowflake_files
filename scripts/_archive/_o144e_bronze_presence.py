#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서17 실증 쿼리를 실행하기 전에 BRONZE 원천 스키마·테이블이 계정 재구축 후 실재하는지 분모를 확보한다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn


def main():
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")

    print("=== 스키마별 테이블 수 ===")
    rows = cur.execute("""
        SELECT TABLE_SCHEMA, COUNT(*) AS N
        FROM GN_DW.INFORMATION_SCHEMA.TABLES
        GROUP BY 1 ORDER BY 1
    """).fetchall()
    for r in rows:
        print("  %-24s %s" % (r[0], r[1]))

    print("\n=== 문서17 이 참조하는 원천 테이블 실재 점검 ===")
    targets = [
        'TM_MM_FDRM_MBER_SPNSR_DSCNTC', 'TD_MS_MSG_AT_SNDNG_DTLS', 'TM_MS_MSG_AT_SNDNG',
        'TM_MM_FDRM_MBER_DVLP_AMT', 'TM_MM_FDRM_MBER_SPNSR_BSNS', 'TM_MM_FDRM_MBER_SPNSR',
        'TM_CM_SPNSR_BSNS_INFO', 'TD_MS_EVENT_PRTCPNT_DTL', 'TM_MS_EMAIL_SNDNG',
        'TD_MS_EMAIL_SNDNG_DTLS', 'TC_CMMN_DTL_CD', 'TC_CMMN_CD', 'TM_CM_MBER_DVLP_GOAL',
        'TM_CM_DEPT_INFO', 'TD_MS_EMAIL_LQY_SNDNG', 'DGT_AD_CMPGN_DTLS',
        'VIDEO_AD_CMPGN_DTLS', 'REBRDC_AD_CMPGN_DTLS', 'TM_CM_CMPGN_MNG',
        'TM_PM_MBRFEE_ACMSLT', 'TD_MS_CRMN_PRTCPNT', 'TM_MS_CRMN', 'TM_MS_EVENT',
        'TM_MM_ONCE_MBER_INFO', 'TM_MM_FDRM_MBER_INFO', 'TM_MS_PSTMTR_SNDNG',
        'TD_MS_MSG_AT_LQY_SNDNG', 'SND_MEMBER_LIST', 'TM_CM_MKTNG_UTM',
    ]
    found = {}
    rows = cur.execute("""
        SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
        FROM GN_DW.INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA LIKE 'BRONZE%'
    """).fetchall()
    for sch, tbl, rc in rows:
        found[tbl.upper()] = (sch, rc)
    missing = []
    for t in targets:
        if t in found:
            sch, rc = found[t]
            print("  🟢 %-32s %-14s rows=%s" % (t, sch, rc))
        else:
            missing.append(t)
            print("  🔴 %-32s 부재" % t)
    print("\n  BRONZE 테이블 총수 = %d · 대상 %d개 중 부재 %d개"
          % (len(found), len(targets), len(missing)))
    if missing:
        print("  🔴 부재 목록: %s" % ", ".join(missing))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
