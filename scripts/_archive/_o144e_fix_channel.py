#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 채널별 반응간격 보강 쿼리가 실패한 원인을 이메일 발송상세 테이블의 실제 컬럼명으로 규명한다.
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn


def main():
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")
    for t in ('TD_MS_EMAIL_SNDNG_DTLS', 'TD_MS_MSG_AT_SNDNG_DTLS', 'TM_MS_PSTMTR_SNDNG'):
        print("\n=== %s ===" % t)
        rows = cur.execute("""
            SELECT COLUMN_NAME, DATA_TYPE FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA='BRONZE_CRM' AND TABLE_NAME=%s
            ORDER BY ORDINAL_POSITION
        """, (t,)).fetchall()
        for r in rows:
            print("  %-28s %s" % (r[0], r[1]))
    print("\nrc_ok")


if __name__ == '__main__':
    main()
