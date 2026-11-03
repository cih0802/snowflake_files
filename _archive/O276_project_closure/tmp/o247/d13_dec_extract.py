#!/usr/bin/env python3
"""O247 · D13 설계 의사결정 대장 추출 — 30_설계_의사결정 조각의 DEC 정의 제목을 기계 추출(읽기 전용).

정의 판정 = 마크다운 제목(#) 줄이면서 'DEC-<n>' 또는 'DEC<n>' 토큰이 있는 줄.
같은 ID 가 여러 제목에 나오면 첫 제목을 정의로 보고 나머지는 '후속 절' 로 센다.
상태 = 제목 선두 이모지(✅ 🟢 🟡 🟠 🔴 🔄 🔵) — 없으면 '(표기 없음)'.
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path("/workspace/20_issue/30_설계_의사결정_조각")
OUT = Path(sys.argv[1])
ID_RE = re.compile(r"DEC-?(\d+)(-[A-Z])?")
STAT = {"✅": "결정", "🟢": "결정", "🟡": "부분 종결", "🟠": "결정 대기",
        "🔴": "충돌·재검토", "🔄": "잠정 확정", "🔵": "비블로커"}

rows, seen = [], {}
for f in sorted(ROOT.glob("30_설계_의사결정-*.md")):
    for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        if not line.startswith("#"):
            continue
        m = ID_RE.search(line)
        if not m:
            continue
        did = f"DEC-{int(m.group(1))}{m.group(2) or ''}"
        title = line.lstrip("#").strip()
        if did in seen:
            seen[did]["후속절"] += 1
            continue
        stat = next((v for k, v in STAT.items() if k in title[:6]), "(표기 없음)")
        dm = re.search(r"20\d\d-\d\d-\d\d", title)
        rec = {"ID": did, "상태": stat, "결정일": dm.group(0) if dm else "",
               "제목": re.sub(r"\s+", " ", title)[:180], "좌표": f"{f.name}:{i}", "후속절": 0}
        seen[did] = rec
        rows.append(rec)

rows.sort(key=lambda r: (int(ID_RE.search(r["ID"]).group(1)), r["ID"]))
with OUT.open("w", encoding="utf-8-sig", newline="") as fh:
    fh.write("# doc_id: D13 · as_of: 2026-10-20 · 설계 의사결정 대장 · 생성 = tmp/o247/d13_dec_extract.py(조각 제목 기계 추출) · 설명 = D13_의사결정_이슈대장.md\n")
    w = csv.DictWriter(fh, fieldnames=["ID", "상태", "결정일", "제목", "좌표", "후속절"])
    w.writeheader()
    w.writerows(rows)
by = {}
for r in rows:
    by[r["상태"]] = by.get(r["상태"], 0) + 1
print(f"DEC {len(rows)} · " + " · ".join(f"{k} {v}" for k, v in sorted(by.items())))
