#!/usr/bin/env python3
"""O250-B · 09_2 절차 집행: [0] SV 실재 → [0-B] 스펙 동기화 → [0-C] 대조 → [1] 버전 기록 → [2] live 소진 → [3] ADD VERSION → [5] 검증.
인자 = 단계(pre | deploy). pre 는 [0]·[0-B]·[0-C]·[1] 까지만 · deploy 는 [2]·[3]·[5]."""
import json
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
    # 🆕 [O273-B] 판정 추가 — 운영계 ZL50263 실측: default 가 VERSION$20 에 고정돼 ADD VERSION($21~$23)이
    #   default 가 되지 않았는데 [5] 는 출력만 하고 rc 0 이었다 ⇒ 「default = 최신 명명 버전」 이 아니면 rc 1
    #   도구 수 = tools 배열 크기(문자열 'tool_spec' 개수는 지시문 본문 언급까지 센다)
    bad = 0
    for a in AGENTS:
        vs = [v for v in versions(a) if v["name"]]
        newest = max(vs, key=lambda v: v["created_on"])["name"] if vs else None
        for v in vs:
            if str(v.get("is_default")).lower() == "true":
                sp = v.get("agent_spec") or ""
                tools = [t.get("tool_spec", {}).get("name") for t in (json.loads(sp).get("tools") or [])] if sp else []
                ok = v["name"] == newest
                bad += not ok
                print("[5]", a, v["name"], "default · 최신", newest, "OK" if ok else "🔴 MISMATCH",
                      "· tools", len(tools), "· pred_axis", "analyst_ml_pred_axis" in tools,
                      "· fee_axis", "analyst_ml_fee_axis" in tools)
                if not ok:
                    print(f"    처방 = ALTER AGENT GN_DW.SERVING.{a} SET DEFAULT_VERSION = '{newest}';  (사람 승인 후 · 53번 참고)")
    sys.exit(1 if bad else 0)
