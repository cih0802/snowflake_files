#!/usr/bin/env python3
"""O224 — native eval v3_0 러너(xh20001 · 데이터셋 O224_*_DS_V3). 규칙 원본 = tmp/o216_eval.py(설정 형식 동일).
사용: python3 tmp/o224_eval.py start <버전> <tag>    # run = o224_<agent>_<tag> · 🔴 과금(승인 후에만)
      python3 tmp/o224_eval.py status <버전> <tag>
버전 = 각 Agent 의 VERSION$N 또는 DEFAULT(별칭 그대로 기록된다)
Co-authored with CoCo
"""
import io
import os
import sys

import snowflake.connector

AGENTS = ['executive', 'member', 'marketing']
D = '/root/w/tmp/o224/'
TPL = """evaluation:
  agent_params:
    agent_name: GN_DW.SERVING.AGENT_{AG}
    agent_type: CORTEX AGENT
    agent_version: {VER}
  source_metadata:
    type: dataset
    dataset_name: GN_DW.SERVING.O224_{AG}_DS_V3
metrics:
  - name: answer_correctness
    version: v3_0
  - name: logical_consistency
    version: v3_0
  - name: tool_selection_accuracy
    version: v3_0
  - name: tool_execution_accuracy
    version: v3_0
"""
mode, ver, tag = sys.argv[1].upper(), sys.argv[2], sys.argv[3]
assert mode in ('START', 'STATUS')
AGENTS = sys.argv[4].split(',') if len(sys.argv) > 4 else AGENTS   # 선택: executive,member,marketing 중 일부
DS = sys.argv[5] if len(sys.argv) > 5 else 'V3'                      # 선택: V3(기준선) | V4
TPL = TPL.replace('_DS_V3', '_DS_' + DS)
os.makedirs(D, exist_ok=True)
token = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                  authenticator='oauth', token=token, role='GN_DW_ADMIN',
                                  warehouse='GN_DW_ETL_WH', database='GN_DW', schema='SERVING')
cur = con.cursor()
cur.execute('CREATE STAGE IF NOT EXISTS GN_DW.SERVING.EVAL_CONFIG_STAGE DIRECTORY = (ENABLE = TRUE)')
for ag in AGENTS:
    name = f'o224_{ag}_{tag}'
    if mode == 'START':
        io.open(D + name + '.resolved.yaml', 'w', encoding='utf-8').write(TPL.format(AG=ag.upper(), VER=ver))
        cur.execute(f"PUT file://{D}{name}.resolved.yaml @GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/ "
                    "AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
    try:
        cur.execute(f"CALL EXECUTE_AI_EVALUATION('{mode}', OBJECT_CONSTRUCT('run_name', '{name}'), "
                    f"'@GN_DW.SERVING.EVAL_CONFIG_STAGE/cortex_project/{name}.resolved.yaml')")
        print(name, str(cur.fetchall())[:300])
    except Exception as e:  # noqa: BLE001
        print('🔴', name, str(e)[:300])
con.close()
