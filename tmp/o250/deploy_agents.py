#!/usr/bin/env python3
"""O250-B · 09_2 절차 집행: [0] SV 실재 → [0-B] 스펙 동기화 → [0-C] 대조 → [1] 버전 기록 → [2] live 소진 → [3] ADD VERSION → [5] 검증.
인자 = 단계(pre | deploy). pre 는 [0]·[0-B]·[0-C]·[1] 까지만 · deploy 는 [2]·[3]·[5]."""
import os
import re
import sys
import time

import snowflake.connector

SRC = open("/workspace/05_SV-Agent_ai/09_2_AGENT_버전업.sql", encoding="utf-8").read()
AGENTS = ["AGENT_MEMBER", "AGENT_EXECUTIVE", "AGENT_MARKETING"]
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                  authenticator="oauth", token=tok, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH",
                                  database="GN_DW")
cur = con.cursor()


def q(s):
    cur.execute(s)
    try:
        return cur.fetchall()
    except Exception:
        return []


def versions(a):
    cur.execute(f"SHOW VERSIONS IN AGENT GN_DW.SERVING.{a}")
    cols = [c[0] for c in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


step = sys.argv[1]
if step == "pre":
    blk0 = re.search(r"WITH required AS \(.*?ORDER BY r\.AGENT_NAME, r\.SV_NAME;", SRC, re.S).group(0)
    miss = q(blk0.rstrip(";"))
    print("[0] 라이브 부재 SV =", len(miss), miss)
    if miss:
        sys.exit(1)
    for a in AGENTS:
        q(f"""COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/{a}/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/{a}/'
  PATTERN = '.*agent_spec[.]yaml'""")
    print("[0-B] COPY FILES 3 OK")
    time.sleep(3)
    src = {re.search(r"AGENT_[A-Z]+", r[0]).group(0): r for r in q(
        "LIST 'snow://workspace/USER$.PUBLIC.\"snowflake_files\"/versions/live/cortex_project/agents/' PATTERN = '.*agent_spec[.]yaml'")}
    dst = {re.search(r"AGENT_[A-Z]+", r[0]).group(0): r for r in q(
        "LIST @GN_DW.OPS.AGENT_SPEC_STAGE PATTERN = '.*agent_spec[.]yaml'")}
    bad = 0
    for a in sorted(set(src) | set(dst)):
        s, d = src.get(a), dst.get(a)
        v = "MISSING_IN_STAGE" if not d else "ORPHAN_IN_STAGE" if not s else "SIZE_MISMATCH" if s[1] != d[1] else "OK"
        bad += v != "OK" and a in AGENTS
        print("[0-C]", a, s and s[1], d and d[1], v)
    for a in AGENTS:
        vs = versions(a)
        dflt = [v["name"] for v in vs if str(v.get("is_default")).lower() == "true"]
        print("[1]", a, "versions", [v["name"] for v in vs], "default", dflt)
    sys.exit(1 if bad else 0)

if step == "deploy":
    for a in AGENTS:
        if any(v["name"] is None for v in versions(a)):
            q(f"ALTER AGENT GN_DW.SERVING.{a} COMMIT COMMENT = 'live 소진(버전업 직전 스냅샷)'")
            print("[2]", a, "committed")
        else:
            print("[2]", a, "no_live")
    for a in AGENTS:
        m = re.search(r"ALTER AGENT GN_DW\.SERVING\." + a + r"\s*\n\s*ADD VERSION FROM [^\n]+\n\s*COMMENT = '[^\n]*';", SRC)
        q(m.group(0).rstrip(";"))
        print("[3]", a, "ADD VERSION OK")
    for a in AGENTS:
        vs = versions(a)
        for v in vs:
            if str(v.get("is_default")).lower() == "true":
                sp = v.get("agent_spec") or ""
                print("[5]", a, v["name"], "default · tool_spec", sp.count("tool_spec"),
                      "· pred_axis", sp.count("analyst_ml_pred_axis") > 0, "· fee_axis", sp.count("analyst_ml_fee_axis") > 0)
