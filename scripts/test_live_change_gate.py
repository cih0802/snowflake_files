#!/usr/bin/env python3
"""음성 테스트 — scripts/live_change_gate.py (O202 · R3-2)

축 ㉠ 오염 = 원장 픽스처에서 해당 행 1개를 지우면 경보 1 · 복원하면 0(뒤집힘 ≥1 · §E6 규격).
축 ㉡ 역방향 오탐 = 객체명은 있지만 날짜가 다른 행은 인정하지 않는다 · 시행일 이전 변경은 보지 않는다.
축 ㉢ 시차 = created_on 다음 날(KST 기재) 행도 인정한다.
"""
import datetime as dt
import io
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import live_change_gate as g  # noqa: E402

ROW = "| 🟢 **`O999`** — SV_TEST 재배포 (2026-10-07 · JU93656) | x | y | z |\n"
OTHER = "| 🟢 **`O998`** — SV_TEST 언급 (2026-09-01) | x | y | z |\n"
D = dt.date(2026, 10, 7)
SINCE = dt.date(2026, 10, 6)
fails = 0


def check(label, cond):
    global fails
    print(("PASS " if cond else "FAIL ") + label)
    fails += 0 if cond else 1


check("㉠ 행 있음 → 경보 0", g.judge([("SV_TEST", D)], [ROW], SINCE) == [])
check("㉠ 행 지움 → 경보 1", len(g.judge([("SV_TEST", D)], [], SINCE)) == 1)
check("㉡ 날짜 다른 행 → 인정 안 함", len(g.judge([("SV_TEST", D)], [OTHER], SINCE)) == 1)
check("㉡ 시행일 이전 변경 → 보지 않음", g.judge([("SV_TEST", dt.date(2026, 10, 3))], [], SINCE) == [])
check("㉢ 다음 날 기재 → 인정", g.judge([("SV_TEST", dt.date(2026, 10, 6))], [ROW], SINCE) == [])

# 종단(CLI · 종료코드) — 픽스처 파일로 행 삭제 → rc=1 · 복원 → rc=0
with tempfile.TemporaryDirectory() as td:
    ch = os.path.join(td, "c.json")
    led = os.path.join(td, "led.md")
    json.dump([{"name": "SV_TEST", "created_on": "2026-10-07"}], io.open(ch, "w", encoding="utf-8"))
    io.open(led, "w", encoding="utf-8").write("# t\n" + ROW)
    cmd = [sys.executable, os.path.join(HERE, "live_change_gate.py"), "--changes-json", ch, "--ledger", led]
    rc_ok = subprocess.run(cmd, stdout=subprocess.DEVNULL, stdin=subprocess.DEVNULL).returncode
    io.open(led, "w", encoding="utf-8").write("# t\n")
    rc_bad = subprocess.run(cmd, stdout=subprocess.DEVNULL, stdin=subprocess.DEVNULL).returncode
    check("종단 행 있음 rc=0", rc_ok == 0)
    check("종단 행 지움 rc=1", rc_bad == 1)

print("결과: 실패 %d" % fails)
sys.exit(1 if fails else 0)
