#!/usr/bin/env python3
"""O226 ⑩ C7 — SILVER 테이블 레벨 COMMENT 를 08_SILVER DDL 정본 문안으로 라이브 반영(대상 10종 · 기본 dry-run)."""
import io, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

SRC = '/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql'
T = ['CRM_MEMBER', 'CRM_MEMBER_STATUS_HIST', 'CRM_MEMBER_RESPONSOR', 'CRM_MEMBER_SPONSOR_BIZ', 'CRM_SPONSOR_RELATION',
     'CRM_PAYMENT_METHOD', 'CRM_ORG', 'CRM_RELATION_ACTIVITY', 'CRM_CODE', 'CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE']
txt = io.open(SRC, encoding='utf-8').read()
cur = conn().cursor() if '--apply' in sys.argv else None
for t in T:
    m = re.search(r'CREATE OR REPLACE TABLE GN_DW\.SILVER\.' + t + r' \(.*?\n\) COMMENT = \'((?:[^\']|\'\')*)\';', txt, re.S)
    if not m:
        sys.exit('🔴 ABORT: 정본 COMMENT 미발견 ' + t)
    sql = f"ALTER TABLE GN_DW.SILVER.{t} SET COMMENT = '{m.group(1)}'"
    print(t, '|', m.group(1)[-90:])
    if cur:
        cur.execute(sql)
print('APPLIED' if cur else 'DRY-RUN')
