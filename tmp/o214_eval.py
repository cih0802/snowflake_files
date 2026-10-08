#!/usr/bin/env python3
"""O214 — native eval v3_0 재측정(O211-B 기준선과 같은 설정 · DEFAULT = VERSION$7) START / STATUS.
사용: python3 tmp/o214_eval.py start | status
Co-authored with CoCo
"""
import os
import sys

import snowflake.connector

RUNS = [('o214_executive_v3_ds2', 'o211_executive_eval_v2'),
        ('o214_member_v3', 'o211_member_eval'),
        ('o214_marketing_v3_ds2', 'o211_marketing_eval_v2')]
STAGE = '@GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/'
token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                  authenticator='oauth', token=token, role='ACCOUNTADMIN',
                                  warehouse='GN_DW_ETL_WH', database='GN_DW', schema='SERVING')
cur = con.cursor()
cur.execute('USE DATABASE GN_DW')
cur.execute('USE SCHEMA SERVING')
mode = sys.argv[1].upper()
for run, cfg in RUNS:
    try:
        cur.execute(f"CALL EXECUTE_AI_EVALUATION('{mode}', OBJECT_CONSTRUCT('run_name', '{run}'), "
                    f"'{STAGE}{cfg}.resolved.yaml')")
        print(run, str(cur.fetchall())[:400])
    except Exception as e:
        print('🔴', run, str(e)[:400])
con.close()
