#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O169 — SV_MEMBER_EVENT 재배포 러너.

🔴 왜 러너 파일인가 = 배포문 본문에 백틱·`$`·`!` 가 섞여 있어 **셸을 경유시키지 않는다**(`R1-7-9`).
🟢 본문은 `CREATE OR ALTER SEMANTIC VIEW` 라 **GRANT·소유권이 보존**된다(`P125` 가드).
🔴 가드 = 실행 전에 `CREATE OR REPLACE` 가 섞였는지 재확인하고, 섞였으면 실행하지 않는다.
🟢 실행 후 라이브 COMMENT 를 되읽어 **도달**을 확인한다(「썼다」와 「닿았다」는 다르다).
"""
import io
import os
import re
import sys

import snowflake.connector

DEPLOY = '/root/deploy_o67/05_2_SV_DDL_MEMBER_EVENT.deploy.sql'
sql = io.open(DEPLOY, encoding='utf-8').read()

print('배포문 %d자' % len(sql))
if 'CREATE OR REPLACE' in sql:
    raise SystemExit('🔴 CREATE OR REPLACE 가 섞였다 — GRANT 파괴 위험 ⇒ 실행 중단')
if not re.search(r'^CREATE OR ALTER SEMANTIC VIEW', sql, re.M):
    raise SystemExit('🔴 CREATE OR ALTER 문을 찾지 못했다 ⇒ 실행 중단')
print('가드 통과 — CREATE OR ALTER 확인 · CREATE OR REPLACE 부재')

tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH',
                          '/snowflake/session/token')).read().strip()
cn = snowflake.connector.connect(
    account=os.environ['SNOWFLAKE_ACCOUNT'],
    host=os.environ['SNOWFLAKE_HOST'],
    token=tok,
    authenticator='oauth',
    warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
    database='GN_DW',
    role=os.environ.get('SNOWFLAKE_ROLE', 'ACCOUNTADMIN'),
)
try:
    n = 0
    for cur in cn.execute_string(sql):
        n += 1
        head = (cur.query or '').strip().split('\n')[0][:88]
        print('  [%02d] %s' % (n, head))
    print('실행 문장 %d개 — 오류 0' % n)

    # 도달 확인 = 라이브 COMMENT 를 되읽는다.
    c = cn.cursor()
    c.execute("""
        select NAME, COMMENT
        from GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS
        where SEMANTIC_VIEW_SCHEMA='SERVING'
          and SEMANTIC_VIEW_NAME='SV_MEMBER_EVENT'
          and NAME in ('DAY_OF_WEEK','CMMN_BRND_NM')
        order by NAME
    """)
    for name, cmt in c.fetchall():
        cmt = cmt or ''
        print('  라이브 %s: len=%d · O169=%s · 16종=%s · 0..6=%s · 일시=%s'
              % (name, len(cmt), '[2026-09-16 O169' in cmt,
                 '실제값 16종' in cmt, "'0'(일)" in cmt or '0''(일)' in cmt,
                 "'일시'" in cmt or "''일시''" in cmt))
finally:
    cn.close()
