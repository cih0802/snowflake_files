#!/usr/bin/env python3
"""D6 기록 없는 라이브 변경 탐지 — SV·Agent created_on 날짜에 원장 §1 행(날짜+객체명)이 있는가

🆕 [O202 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료 · 설계 = `20_issue/_o201_inspection_evidence.md` §E6]
🔴 분류 = `JUDGE`. 종료코드가 판정이다 — 무기록 변경이 1건이라도 있으면 1, 없으면 0.
🔴 음성 테스트 = `scripts/test_live_change_gate.py`(`R3-2`).

판정식(§E6)
    라이브 변경 시각 t(`SHOW SEMANTIC VIEWS`·`SHOW AGENTS` 의 created_on)마다
    원장 §1 상태 대시보드에 「t 의 날짜 · 대상 객체명」 을 **함께 담은 행**이 있는가.
    부재 ⇒ 🔴 경보(무기록 변경).

경계(설계 판단 · 문서에 적어 둔다)
    · 날짜 = created_on 의 계정 시간대 날짜와 그 다음 날(KST 기재 관례 · 시차 흡수) 둘 중 하나면 인정.
    · 시행일 `--since`(기본 2026-10-06 = O202 시행) 이전 변경은 보지 않는다 —
      그 이전 재구축(2026-10-03 런북 일괄 생성)은 객체명을 행마다 적는 규약이 없던 시기다.
    · 🔴 [O207 정정] created_on 은 **최초 생성 시각**이다(CREATE OR ALTER·ADD VERSION 이 바꾸지 않는다) ⇒
      Agent = SHOW VERSIONS 의 버전 created_on · SV = INFORMATION_SCHEMA.QUERY_HISTORY 의 CREATE OR … SEMANTIC VIEW 성공 이력(최근 7일 · 실행자 가시 범위).

사용
    python3 scripts/live_change_gate.py                 # 라이브 조회 + 판정
    python3 scripts/live_change_gate.py --since 2026-10-03
    python3 scripts/live_change_gate.py --changes-json <파일>   # 오프라인(테스트용) — [{"name":..,"created_on":"YYYY-MM-DD"}]
"""
import argparse
import datetime as dt
import glob
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LEDGER_GLOB = os.path.join(ROOT, "20_issue", "00_INDEX_이슈원장_조각", "00_INDEX_이슈원장-*.md")
SHOWS = (
    "SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING",
    "SHOW AGENTS IN SCHEMA GN_DW.SERVING",
)
ROW_LABEL = re.compile(r"^\|\s*\S*\s*\*\*`O\d+")
SV_DDL = re.compile(r"SEMANTIC\s+VIEW\s+GN_DW\.SERVING\.(\w+)", re.I)
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")


def ledger_rows(paths):
    """원장 §1 대시보드 행 = 「| <상태> **`O<번호>…`** …」 형태의 표 행."""
    rows = []
    for p in paths:
        for line in io.open(p, encoding="utf-8"):
            if ROW_LABEL.match(line):
                rows.append(line)
    return rows


def judge(changes, rows, since):
    """경보 목록을 돌려준다. changes = [(name, date)] · rows = 원장 §1 행 문자열."""
    alarms = []
    for name, day in changes:
        if day < since:
            continue
        ok_days = {day.isoformat(), (day + dt.timedelta(days=1)).isoformat()}
        hit = any(name in r and ok_days & set(DATE.findall(r)) for r in rows)
        if not hit:
            alarms.append((name, day.isoformat()))
    return alarms


def live_changes():
    import snowflake.connector

    tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
    conn = snowflake.connector.connect(
        account=os.environ.get("SNOWFLAKE_ACCOUNT"),
        host=os.environ.get("SNOWFLAKE_HOST"),
        authenticator="oauth",
        token=tok,
    )
    out = []
    try:
        cur = conn.cursor()
        for q in SHOWS:
            cur.execute(q)
            cols = [d[0] for d in cur.description]
            ci, ni = cols.index("created_on"), cols.index("name")
            for r in cur.fetchall():
                out.append((r[ni], r[ci].date()))
        # 🆕 [O207] created_on 은 **최초 생성 시각**이다 — CREATE OR ALTER SEMANTIC VIEW · ALTER AGENT ADD VERSION 은
        #   그 값을 바꾸지 않는다(실측 2026-10-07: SV_MSTR_SPNSR_DVLP 당일 ALTER 후에도 created_on = 2026-10-06).
        #   ⇒ 종전 「--since 이후 변경 0」 은 거짓 음성이었다. 보강 = ① Agent 버전 created_on ② SV DDL 질의 이력.
        agents = [n for n, _ in out if n.startswith("AGENT_")]
        for a in agents:
            cur.execute("SHOW VERSIONS IN AGENT GN_DW.SERVING.%s" % a)
            cols = [d[0] for d in cur.description]
            ci = cols.index("created_on")
            for r in cur.fetchall():
                out.append((a, r[ci].date()))
        cur.execute(
            "SELECT QUERY_TEXT, START_TIME FROM TABLE(GN_DW.INFORMATION_SCHEMA.QUERY_HISTORY("
            "RESULT_LIMIT => 10000)) WHERE EXECUTION_STATUS = 'SUCCESS' "
            "AND QUERY_TEXT ILIKE 'CREATE OR %SEMANTIC VIEW GN_DW.SERVING.%'")
        for text, ts in cur.fetchall():
            m = SV_DDL.search(text)
            if m:
                out.append((m.group(1).upper(), ts.date()))
    finally:
        conn.close()
    return sorted(set(out))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", default="2026-10-06")
    ap.add_argument("--changes-json")
    ap.add_argument("--ledger", nargs="*")
    a = ap.parse_args(argv)
    since = dt.date.fromisoformat(a.since)
    if a.changes_json:
        raw = json.load(io.open(a.changes_json, encoding="utf-8"))
        changes = [(c["name"], dt.date.fromisoformat(c["created_on"])) for c in raw]
    else:
        changes = live_changes()
    paths = a.ledger if a.ledger else sorted(glob.glob(LEDGER_GLOB))
    rows = ledger_rows(paths)
    alarms = judge(changes, rows, since)
    seen = sum(1 for _, d in changes if d >= since)
    print("대상 = 변경 %d건(시행일 %s 이후 %d) · 원장 §1 행 %d" % (len(changes), since, seen, len(rows)))
    for n, d in alarms:
        print("  🔴 무기록 변경: %s (%s) — 원장 §1 에 이 날짜·객체명 행이 없다" % (n, d))
    if alarms:
        print("🔴 FAIL — 무기록 라이브 변경 %d건" % len(alarms))
        return 1
    print("✅ 게이트 통과 — 무기록 라이브 변경 0건")
    return 0


if __name__ == "__main__":
    sys.exit(main())
