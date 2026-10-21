"""O256-B — 직전 빌드 이후 바뀐 원본이 누구의 변경인지 판정(읽기 전용)."""
import os, sys, time
sys.path.insert(0, "/workspace/95_작업기록_인수인계정제/tools")
from clean80 import strip_comments
W = "/workspace/"; B = W + "95_작업기록_인수인계정제/_backup_O256_원본_20261021/"
for rel in ["02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql", "02_GN_DW_building/08_After_Deploy_DBT.sql",
            "05_SV-Agent_ai/05_02_SV_DDL_MEMBER_EVENT.sql", "05_SV-Agent_ai/05_05_SV_DDL_EVENT_PARTICIPATION.sql",
            "05_SV-Agent_ai/05_13_SV_DDL_DEPT_AGGR.sql", "05_SV-Agent_ai/05_16_SV_DDL_BUDGET_YEARLY.sql",
            "05_SV-Agent_ai/05_17_SV_DDL_MEMBER_STATUS_ASOF.sql"]:
    cur = open(W + rel, encoding="utf-8").read(); bak = open(B + rel, encoding="utf-8").read()
    mt = time.strftime("%H:%M:%S", time.gmtime(os.path.getmtime(W + rel)))
    print(f"{mt}Z · 헤더 {'-- Purpose    :' in cur[:3000]} · 코드=백업 {strip_comments(cur) == strip_comments(bak)} · "
          f"{len(bak)}→{len(cur)}B · {rel}")
