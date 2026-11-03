#!/usr/bin/env python3
"""O216 — native eval v3_0 러너(버전 · 데이터셋 지정). o215_eval.py 를 데이터셋 V2/V3 선택형으로 일반화.
사용: python3 tmp/o216_eval.py start VERSION$3 v2 base3   # run = o216_<agent>_<ds>_<tag>
      python3 tmp/o216_eval.py status VERSION$3 v2 base3
Co-authored with CoCo
"""
import io
import os
import sys

import snowflake.connector

BASE = [('executive', 'o211_executive_eval_v2'), ('member', 'o211_member_eval'), ('marketing', 'o211_marketing_eval_v2')]
DS_V3 = {'executive': 'GN_DW.SERVING.O216_EXECUTIVE_DS_V3', 'member': 'GN_DW.SERVING.O216_MEMBER_DS_V3',
         'marketing': 'GN_DW.SERVING.O216_MARKETING_DS_V3'}
D = '/workspace/tmp/o215/'
mode, ver, ds, tag = sys.argv[1].upper(), sys.argv[2], sys.argv[3], sys.argv[4]
assert ds in ('v2', 'v3')
token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                  authenticator='oauth', token=token, role='GN_DW_ADMIN',  # O216-B: ACCOUNTADMIN → GN_DW_ADMIN
                                  warehouse='GN_DW_ETL_WH', database='GN_DW', schema='SERVING')
cur = con.cursor()
cur.execute('USE DATABASE GN_DW')
cur.execute('USE SCHEMA SERVING')
for ag, cfg in BASE:
    name = f'o216_{ag}_{ds}_{tag}'
    if mode == 'START':
        src = io.open(D + cfg + '.resolved.yaml', encoding='utf-8').read()
        assert 'agent_version: DEFAULT' in src
        src = src.replace('agent_version: DEFAULT', f'agent_version: {ver}')
        if ds == 'v3':
            old = [ln for ln in src.splitlines() if 'dataset_name:' in ln][0]
            src = src.replace(old, old.split('dataset_name:')[0] + 'dataset_name: ' + DS_V3[ag])
        io.open(D + name + '.resolved.yaml', 'w', encoding='utf-8').write(src)
        cur.execute(f"PUT file://{D}{name}.resolved.yaml @GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
    try:
        cur.execute(f"CALL EXECUTE_AI_EVALUATION('{mode}', OBJECT_CONSTRUCT('run_name', '{name}'), "
                    f"'@GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/{name}.resolved.yaml')")
        print(name, str(cur.fetchall())[:300])
    except Exception as e:  # noqa: BLE001
        print('🔴', name, str(e)[:300])
con.close()
