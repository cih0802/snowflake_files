#!/usr/bin/env python3
"""O215 — native eval v3_0 러너(버전 지정). O211-B 설정 3종을 agent_version 만 바꿔 스테이지에 올리고 START/STATUS.
사용: python3 tmp/o215_eval.py start VERSION$6 v6     # run = o215_<agent>_<tag>
      python3 tmp/o215_eval.py status VERSION$6 v6
Co-authored with CoCo
"""
import io
import os
import sys

import snowflake.connector

BASE = [('executive', 'o211_executive_eval_v2'), ('member', 'o211_member_eval'), ('marketing', 'o211_marketing_eval_v2')]
D = '/workspace/tmp/o215/'
mode, ver, tag = sys.argv[1].upper(), sys.argv[2], sys.argv[3]
token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                  authenticator='oauth', token=token, role='ACCOUNTADMIN',
                                  warehouse='GN_DW_ETL_WH', database='GN_DW', schema='SERVING')
cur = con.cursor()
cur.execute('USE DATABASE GN_DW')
cur.execute('USE SCHEMA SERVING')
for ag, cfg in BASE:
    name = f'o215_{ag}_{tag}'
    if mode == 'START':
        src = io.open(D + cfg + '.resolved.yaml', encoding='utf-8').read()
        assert 'agent_version: DEFAULT' in src
        io.open(D + name + '.resolved.yaml', 'w', encoding='utf-8').write(src.replace('agent_version: DEFAULT', f'agent_version: {ver}'))
        cur.execute(f"PUT file://{D}{name}.resolved.yaml @GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
    try:
        cur.execute(f"CALL EXECUTE_AI_EVALUATION('{mode}', OBJECT_CONSTRUCT('run_name', '{name}'), "
                    f"'@GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/{name}.resolved.yaml')")
        print(name, str(cur.fetchall())[:300])
    except Exception as e:  # noqa: BLE001
        print('🔴', name, str(e)[:300])
con.close()
